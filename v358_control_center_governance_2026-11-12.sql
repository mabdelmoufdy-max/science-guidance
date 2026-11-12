-- v358 مركز التحكم — المرحلة 4: استثناءات مؤقتة لشخص، مراجعة الصلاحيات، «اعرض كمستخدم» (قراءة فقط)، والتراجع عن أفعال المركز

create table if not exists public.permission_grants(
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  capability text not null references public.permission_capabilities(code) on update cascade,
  allowed boolean not null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  reason text,
  created_by uuid,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid,
  check (expires_at > starts_at)
);
create index if not exists permission_grants_lookup on public.permission_grants(profile_id, capability);
create table if not exists public.access_reviews(
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  decision text not null check (decision in ('keep','revoke')),
  reason text,
  reviewed_by uuid,
  reviewed_at timestamptz not null default now()
);
alter table public.permission_grants enable row level security;
alter table public.access_reviews enable row level security;
revoke all on public.permission_grants from anon, authenticated;
revoke all on public.access_reviews from anon, authenticated;

-- الاستثناء الساري للشخص يسبق قاعدة دوره (السماح يرفع منع الدور فقط؛ لا يتجاوز سياسات القاعدة الأصلية)
create or replace function private.cap_allowed(p_cap text) returns boolean
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_role public.app_role; v_g boolean;
begin
  if auth.uid() is null then return true; end if;
  v_role := private.current_app_role();
  if v_role is null or v_role = 'admin' then return true; end if;
  select g.allowed into v_g from public.permission_grants g
   where g.profile_id = auth.uid() and g.capability = p_cap and g.revoked_at is null
     and now() >= g.starts_at and now() < g.expires_at
   order by g.created_at desc limit 1;
  if found then return v_g; end if;
  return coalesce((select allowed from public.permission_rules where capability = p_cap and role = v_role), true);
end $fn$;

create or replace function public.admin_grant_add(p_profile uuid, p_cap text, p_allowed boolean, p_days int, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_id uuid; v_exp timestamptz;
begin
  if p_days is null or p_days < 1 or p_days > 90 then raise exception 'المدة من يوم إلى 90 يومًا'; end if;
  if not exists(select 1 from public.profiles where id = p_profile) then raise exception 'الحساب غير موجود'; end if;
  if not exists(select 1 from public.permission_capabilities where code = p_cap) then raise exception 'إجراء غير معروف'; end if;
  if exists(select 1 from public.user_roles where profile_id = p_profile and role = 'admin' and is_active) then raise exception 'مدير النظام لا يحتاج استثناءً'; end if;
  v_exp := now() + make_interval(days => p_days);
  insert into public.permission_grants(profile_id, capability, allowed, expires_at, reason, created_by)
  values (p_profile, p_cap, p_allowed, v_exp, nullif(p_reason,''), v_actor) returning id into v_id;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_grant_add', 'permission_grant', v_id::text, null,
          jsonb_build_object('profile_id', p_profile, 'cap', p_cap, 'allowed', p_allowed, 'expires_at', v_exp, 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true, 'id', v_id, 'expires_at', v_exp);
end $fn$;

create or replace function public.admin_grant_revoke(p_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_n int;
begin
  update public.permission_grants set revoked_at = now(), revoked_by = v_actor where id = p_id and revoked_at is null;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'الاستثناء غير موجود أو أُلغي من قبل'; end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_grant_revoke', 'permission_grant', p_id::text, null, jsonb_build_object('reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true);
end $fn$;

create or replace function public.admin_grants_list()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
begin
  perform private.v356_require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', g.id, 'profile_id', g.profile_id, 'name', p.full_name, 'cap', g.capability, 'label', c.label, 'allowed', g.allowed,
      'starts_at', g.starts_at, 'expires_at', g.expires_at, 'reason', g.reason, 'created_at', g.created_at, 'created_by_name', cb.full_name,
      'revoked_at', g.revoked_at,
      'status', case when g.revoked_at is not null then 'revoked' when now() >= g.expires_at then 'expired' else 'active' end)
      order by (g.revoked_at is null and now() < g.expires_at) desc, g.created_at desc)
    from public.permission_grants g
    join public.profiles p on p.id = g.profile_id
    join public.permission_capabilities c on c.code = g.capability
    left join public.profiles cb on cb.id = g.created_by
    where g.created_at > now() - interval '120 days'), '[]'::jsonb);
end $fn$;

-- مراجعة الصلاحيات: كل دور نشط لكل حساب، مع آخر مراجعة واقتراح
create or replace function public.admin_access_review_list()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
begin
  perform private.v356_require_admin();
  return coalesce((select jsonb_agg(x order by (x->>'suggest') is null, x->>'name', x->>'role') from (
    select jsonb_build_object(
      'profile_id', ur.profile_id, 'name', p.full_name, 'role', ur.role::text, 'account_active', p.is_active,
      'assigned_at', ur.assigned_at, 'last_sign_in_at', au.last_sign_in_at,
      'actions30', (select count(*) from public.audit_log a where a.actor_profile_id = ur.profile_id and a.actor_role = ur.role and a.created_at > now() - interval '30 days'),
      'last_review', (select jsonb_build_object('decision', r.decision, 'at', r.reviewed_at, 'reason', r.reason) from public.access_reviews r where r.profile_id = ur.profile_id and r.role = ur.role order by r.reviewed_at desc limit 1),
      'suggest', case
        when not p.is_active then 'الحساب معطل والدور ما زال نشطًا'
        when ur.role = 'stage_coordinator' and not exists(select 1 from public.supervisors s join public.stage_coordinator_assignments c on c.supervisor_id = s.id and c.active where s.profile_id = ur.profile_id) then 'منسق بلا مرحلة'
        when ur.role = 'supervisor' and not exists(select 1 from public.supervisors s where s.profile_id = ur.profile_id and (exists(select 1 from public.schools sc where sc.supervisor_id = s.id) or exists(select 1 from public.supervisor_school_subjects ss where ss.supervisor_id = s.id and ss.active))) then 'موجه بلا مدارس'
        when au.last_sign_in_at is null or au.last_sign_in_at < now() - interval '30 days' then 'لم يدخل منذ 30 يومًا أو أكثر'
        else null end,
      'revocable', ur.role::text = any(array['stage_coordinator','supervisor','first_supervisor','teacher','school_manager'])
    ) x
    from public.user_roles ur
    join public.profiles p on p.id = ur.profile_id
    left join auth.users au on au.id = ur.profile_id
    where ur.is_active) t), '[]'::jsonb);
end $fn$;

create or replace function public.admin_access_review_decide(p_profile uuid, p_role text, p_decision text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin();
begin
  if p_decision not in ('keep','revoke') then raise exception 'قرار غير صحيح'; end if;
  if not exists(select 1 from public.user_roles where profile_id = p_profile and role::text = p_role and is_active) then raise exception 'الدور غير نشط لهذا الحساب'; end if;
  if p_decision = 'revoke' then
    perform public.admin_account_action(p_profile, 'role_off', p_role, coalesce(nullif(p_reason,''), 'مراجعة الصلاحيات'));
  end if;
  insert into public.access_reviews(profile_id, role, decision, reason, reviewed_by)
  values (p_profile, p_role::public.app_role, p_decision, nullif(p_reason,''), v_actor);
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_review', 'profile', p_profile::text, null, jsonb_build_object('role', p_role, 'decision', p_decision, 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true);
end $fn$;

-- «اعرض كمستخدم»: يحسب ما يراه الحساب بدور معيّن وما يستطيع فعله، دون أي كتابة، ثم يعيد هوية المدير
create or replace function public.admin_view_as(p_profile uuid, p_role text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  v_actor uuid := private.v356_require_admin();
  v_claims text := current_setting('request.jwt.claims', true);
  v_headers text := current_setting('request.headers', true);
  v_eff text; v_sch uuid[]; v_tch uuid[]; v_caps jsonb; v_res jsonb;
begin
  if not exists(select 1 from public.user_roles where profile_id = p_profile and role::text = p_role and is_active) then
    raise exception 'هذا الدور غير نشط لهذا الحساب';
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_profile, 'role', 'authenticated')::text, true);
    perform set_config('request.headers', json_build_object('x-app-role', p_role)::text, true);
    v_eff := private.current_app_role()::text;
    v_sch := coalesce(private.accessible_school_ids(), '{}');
    v_tch := coalesce(private.v336_visible_teacher_ids(), '{}');
    select coalesce(jsonb_agg(jsonb_build_object('code', c.code, 'label', c.label, 'allowed', private.cap_allowed(c.code),
             'by_grant', exists(select 1 from public.permission_grants g where g.profile_id = p_profile and g.capability = c.code and g.revoked_at is null and now() >= g.starts_at and now() < g.expires_at)) order by c.sort), '[]'::jsonb)
      into v_caps from public.permission_capabilities c;
  exception when others then
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    perform set_config('request.headers', coalesce(v_headers, ''), true);
    raise;
  end;
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.headers', coalesce(v_headers, ''), true);
  select jsonb_build_object(
    'role', p_role, 'effective_role', v_eff,
    'schools_count', coalesce(array_length(v_sch, 1), 0),
    'teachers_count', coalesce(array_length(v_tch, 1), 0),
    'by_stage', coalesce((select jsonb_object_agg(stage, n) from (select sc.stage, count(*) n from public.schools sc where sc.id = any(v_sch) group by sc.stage) s), '{}'::jsonb),
    'schools', coalesce((select jsonb_agg(jsonb_build_object('name', sc.name, 'stage', sc.stage) order by sc.stage, sc.name) from (select * from public.schools where id = any(v_sch) order by stage, name limit 300) sc), '[]'::jsonb),
    'capabilities', v_caps)
  into v_res;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_view_as', 'profile', p_profile::text, null, jsonb_build_object('role', p_role));
  return v_res;
end $fn$;

-- التراجع عن فعل من أفعال مركز التحكم (مرة واحدة لكل فعل)
create or replace function public.admin_revert_action(p_audit_id bigint, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  v_actor uuid := private.v356_require_admin();
  a public.audit_log%rowtype; v_p uuid; v_val text; e jsonb; v_inv jsonb := '[]'::jsonb; v_n int := 0; v_k int; v_r text := coalesce(nullif(p_reason,''), 'تراجع');
begin
  select * into a from public.audit_log where id = p_audit_id;
  if not found then raise exception 'السطر غير موجود'; end if;
  if exists(select 1 from public.audit_log where action = 'cc_revert' and entity_id = p_audit_id::text) then raise exception 'تم التراجع عن هذا الفعل من قبل'; end if;
  v_val := a.new_data->>'value';
  if a.action in ('cc_disable','cc_enable','cc_force_password','cc_role_on','cc_role_off','cc_coord_stage_on','cc_coord_stage_off') then
    v_p := a.entity_id::uuid;
    if a.action = 'cc_disable' then perform public.admin_account_action(v_p, 'enable', null, v_r);
    elsif a.action = 'cc_enable' then perform public.admin_account_action(v_p, 'disable', null, v_r);
    elsif a.action = 'cc_force_password' then perform public.admin_account_action(v_p, 'force_password', (a.old_data->>'must_change_password'), v_r);
    elsif a.action = 'cc_role_on' then perform public.admin_account_action(v_p, 'role_off', v_val, v_r);
    elsif a.action = 'cc_role_off' then perform public.admin_account_action(v_p, 'role_on', v_val, v_r);
    elsif a.action = 'cc_coord_stage_on' then perform public.admin_account_action(v_p, 'coord_stage_off', v_val, v_r);
    elsif a.action = 'cc_coord_stage_off' then perform public.admin_account_action(v_p, 'coord_stage_on', v_val, v_r);
    end if;
  elsif a.action = 'cc_flag' then
    perform public.admin_set_flag(a.entity_id, (a.old_data->>a.entity_id)::boolean, v_r);
  elsif a.action = 'cc_permissions' then
    for e in select * from jsonb_array_elements(a.new_data->'changes') loop
      v_inv := v_inv || jsonb_build_object('cap', e->>'cap', 'role', e->>'role', 'allowed', (e->>'from')::boolean);
    end loop;
    perform public.admin_set_permissions(v_inv, v_r);
  elsif a.action = 'cc_grant_add' then
    perform public.admin_grant_revoke(a.entity_id::uuid, v_r);
  elsif a.action = 'cc_move_schools' then
    for e in select * from jsonb_array_elements(a.old_data->'schools') loop
      if not coalesce((e->>'same')::boolean, false) then
        update public.schools set supervisor_id = nullif(e->>'from_id','')::uuid
        where id = (e->>'id')::uuid and supervisor_id::text = a.entity_id;
        get diagnostics v_k = row_count; v_n := v_n + v_k;
      end if;
    end loop;
  else
    raise exception 'لا يمكن التراجع عن هذا النوع من الأفعال من هنا';
  end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_revert', 'audit_log', p_audit_id::text, jsonb_build_object('action', a.action), jsonb_build_object('reason', nullif(p_reason,''), 'schools_restored', v_n));
  return jsonb_build_object('ok', true, 'action', a.action, 'schools_restored', v_n);
end $fn$;

-- تعديل v356: رفض واضح قبل التطبيق إن لم يكن الموجه الجديد مسجّلًا في مرحلة المدرسة (المشغل enforce_school_identity يرفضه أصلًا)
create or replace function public.admin_move_schools(p_school_ids uuid[], p_to_supervisor uuid, p_apply boolean default false, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  v_actor uuid := private.v356_require_admin();
  v_to public.supervisors%rowtype; v_rows jsonb; v_bad int; v_n int := 0; v_stage text;
begin
  if p_school_ids is null or cardinality(p_school_ids) = 0 then raise exception 'اختر مدرسة واحدة على الأقل'; end if;
  if cardinality(p_school_ids) > 100 then raise exception 'الحد 100 مدرسة في المرة'; end if;
  select * into v_to from public.supervisors where id = p_to_supervisor;
  if not found or not v_to.active then raise exception 'الموجه الجديد غير موجود أو غير نشط'; end if;
  select count(*) into v_bad from public.schools where id = any(p_school_ids) and stage like 'ثانوي%';
  if v_bad > 0 then raise exception 'مدارس الثانوي تُسند بالمادة من شاشة إدخال بيانات المدارس، لا من هنا'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', sc.id, 'name', sc.name, 'stage', sc.stage,
      'from_id', sc.supervisor_id, 'from_name', fs.full_name,
      'same', sc.supervisor_id is not distinct from p_to_supervisor,
      'teachers', (select count(*) from public.teacher_records tr where tr.home_school_id = sc.id and tr.active),
      'pending', (select count(*) from public.school_submissions s where s.school_id = sc.id and s.status::text like 'pending%'),
      'stage_ok', exists(select 1 from public.supervisor_stage_assignments a where a.supervisor_id = p_to_supervisor and a.stage = sc.stage and a.active)
    ) order by sc.name), '[]'::jsonb)
  into v_rows
  from public.schools sc left join public.supervisors fs on fs.id = sc.supervisor_id
  where sc.id = any(p_school_ids);
  if p_apply then
    select x->>'stage' into v_stage from jsonb_array_elements(v_rows) x where not (x->>'stage_ok')::boolean and not (x->>'same')::boolean limit 1;
    if v_stage is not null then
      raise exception 'الموجه % غير مسجّل في مرحلة «%» — سجّل مراحله أولًا من شاشة الموجهين', v_to.full_name, v_stage;
    end if;
    update public.schools set supervisor_id = p_to_supervisor
    where id = any(p_school_ids) and supervisor_id is distinct from p_to_supervisor;
    get diagnostics v_n = row_count;
    insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
    values (v_actor, 'admin', 'cc_move_schools', 'schools', p_to_supervisor::text,
      jsonb_build_object('schools', v_rows),
      jsonb_build_object('to_supervisor', p_to_supervisor, 'to_name', v_to.full_name, 'moved', v_n, 'reason', nullif(p_reason,'')));
  end if;
  return jsonb_build_object('to_name', v_to.full_name, 'applied', p_apply, 'moved', v_n, 'schools', v_rows);
end $fn$;

revoke all on function public.admin_grant_add(uuid,text,boolean,int,text) from public, anon;
revoke all on function public.admin_grant_revoke(uuid,text) from public, anon;
revoke all on function public.admin_grants_list() from public, anon;
revoke all on function public.admin_access_review_list() from public, anon;
revoke all on function public.admin_access_review_decide(uuid,text,text,text) from public, anon;
revoke all on function public.admin_view_as(uuid,text) from public, anon;
revoke all on function public.admin_revert_action(bigint,text) from public, anon;
grant execute on function public.admin_grant_add(uuid,text,boolean,int,text) to authenticated;
grant execute on function public.admin_grant_revoke(uuid,text) to authenticated;
grant execute on function public.admin_grants_list() to authenticated;
grant execute on function public.admin_access_review_list() to authenticated;
grant execute on function public.admin_access_review_decide(uuid,text,text,text) to authenticated;
grant execute on function public.admin_view_as(uuid,text) to authenticated;
grant execute on function public.admin_revert_action(bigint,text) to authenticated;
