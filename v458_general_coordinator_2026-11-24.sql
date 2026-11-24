-- v458: دور «المنسق العام» (الخطة 3: منسق مرحلة بكل المراحل + قدرة عابرة للمراحل مغلقة افتراضيًا)
-- إضافي فقط: لا يغيّر سلوك أي مستخدم حالي. التعيين بيد مدير النظام وحده.

create table if not exists public.general_coordinators(
  profile_id uuid primary key,
  active boolean not null default true,
  granted_by uuid,
  granted_at timestamptz not null default now(),
  note text,
  updated_at timestamptz not null default now()
);
alter table public.general_coordinators enable row level security;
revoke all on public.general_coordinators from anon, authenticated;

insert into public.permission_capabilities(code, label, description, sort, kind)
values ('cross.move_schools', 'نقل مدارس بين الموجهين (كل المراحل)',
        'للمنسق العام فقط: نقل مدارس الابتدائي والإعدادي من موجه إلى آخر. مغلق افتراضيًا ويُفتح بالتعيين كمنسق عام.',
        (select coalesce(max(sort), 0) + 1 from public.permission_capabilities), 'widen')
on conflict (code) do nothing;

-- منسق عام = سجل نشط + دور منسق مرحلة نشط + إسنادات نشطة للمراحل الأربع كلها
create or replace function private.is_general_coordinator(p_profile uuid)
returns boolean language sql stable security definer set search_path to 'public','pg_temp' as $$
  select p_profile is not null
    and exists(select 1 from public.general_coordinators g where g.profile_id = p_profile and g.active)
    and exists(select 1 from public.user_roles ur where ur.profile_id = p_profile and ur.role::text = 'stage_coordinator' and ur.is_active)
    and (select count(distinct sca.stage) from public.stage_coordinator_assignments sca
           join public.supervisors s on s.id = sca.supervisor_id
          where s.profile_id = p_profile and s.active and sca.active
            and sca.stage in ('ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي')) = 4
$$;

create or replace function public.my_coordinator_scope()
returns jsonb language plpgsql stable security definer set search_path to 'public','pg_temp' as $$
begin
  if auth.uid() is null then return jsonb_build_object('general', false, 'stages', '[]'::jsonb); end if;
  return jsonb_build_object(
    'general', private.current_app_role()::text = 'stage_coordinator' and private.is_general_coordinator(auth.uid()),
    'stages', coalesce((select jsonb_agg(distinct sca.stage) from public.stage_coordinator_assignments sca
                          join public.supervisors s on s.id = sca.supervisor_id
                         where s.profile_id = auth.uid() and s.active and sca.active), '[]'::jsonb));
end $$;

create or replace function public.admin_set_general_coordinator(p_profile uuid, p_on boolean, p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare
  v_actor uuid := private.v356_require_admin();
  v_sup uuid; v_st text; v_cap constant text := 'cross.move_schools';
begin
  select id into v_sup from public.supervisors where profile_id = p_profile and active;
  if v_sup is null then raise exception 'الحساب ليس له سجل موجه/منسق نشط'; end if;
  if exists(select 1 from public.user_roles where profile_id = p_profile and role::text = 'admin' and is_active) then
    raise exception 'مدير النظام لا يحتاج دور المنسق العام';
  end if;
  if p_on then
    if not exists(select 1 from public.user_roles where profile_id = p_profile and role::text = 'stage_coordinator' and is_active) then
      raise exception 'فعّل دور «منسق المرحلة» للحساب أولًا من «تعديل الأدوار»';
    end if;
    foreach v_st in array array['ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي'] loop
      update public.stage_coordinator_assignments set active = true where supervisor_id = v_sup and stage = v_st and not active;
      insert into public.stage_coordinator_assignments(supervisor_id, stage, active, assigned_by)
      select v_sup, v_st, true, v_actor
       where not exists(select 1 from public.stage_coordinator_assignments where supervisor_id = v_sup and stage = v_st);
    end loop;
    insert into public.general_coordinators(profile_id, active, granted_by, note)
    values (p_profile, true, v_actor, nullif(p_reason, ''))
    on conflict (profile_id) do update set active = true, granted_by = v_actor, note = nullif(p_reason, ''), updated_at = now();
    update public.permission_grants set revoked_at = now(), revoked_by = v_actor
     where profile_id = p_profile and capability = v_cap and revoked_at is null;
    insert into public.permission_grants(profile_id, capability, allowed, expires_at, reason, created_by)
    values (p_profile, v_cap, true, null, 'منسق عام', v_actor);
  else
    update public.general_coordinators set active = false, updated_at = now() where profile_id = p_profile;
    update public.permission_grants set revoked_at = now(), revoked_by = v_actor
     where profile_id = p_profile and capability = v_cap and revoked_at is null;
  end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_general_coordinator', 'profiles', p_profile::text, null,
          jsonb_build_object('on', p_on, 'reason', nullif(p_reason, '')));
  return jsonb_build_object('ok', true, 'on', p_on, 'valid', private.is_general_coordinator(p_profile));
end $$;

create or replace function public.admin_general_coordinators()
returns jsonb language plpgsql stable security definer set search_path to 'public','pg_temp' as $$
begin
  perform private.v356_require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object(
      'profile_id', g.profile_id, 'active', g.active, 'valid', private.is_general_coordinator(g.profile_id),
      'name', (select s.full_name from public.supervisors s where s.profile_id = g.profile_id limit 1),
      'since', g.granted_at) order by g.granted_at) from public.general_coordinators g), '[]'::jsonb);
end $$;

-- نقل مدارس الابتدائي/الإعدادي بين الموجهين للمنسق العام (نفس منطق admin_move_schools بصلاحيات المنسق العام)
create or replace function public.coordinator_move_schools(p_school_ids uuid[], p_to_supervisor uuid, p_apply boolean default false, p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare
  v_actor uuid := auth.uid();
  v_to public.supervisors%rowtype; v_rows jsonb; v_bad int; v_n int := 0; v_stage text;
begin
  if v_actor is null or private.current_app_role()::text is distinct from 'stage_coordinator'
     or not private.is_general_coordinator(v_actor) then
    raise exception 'غير مصرح: هذه العملية للمنسق العام فقط' using errcode = '42501';
  end if;
  if not private.cap_allowed_for(v_actor, 'stage_coordinator', 'cross.move_schools') then
    raise exception 'هذا الإجراء موقوف لدورك من مركز التحكم: نقل مدارس بين الموجهين' using errcode = '42501';
  end if;
  if p_school_ids is null or cardinality(p_school_ids) = 0 then raise exception 'اختر مدرسة واحدة على الأقل'; end if;
  if cardinality(p_school_ids) > 100 then raise exception 'الحد 100 مدرسة في المرة'; end if;
  select * into v_to from public.supervisors where id = p_to_supervisor;
  if not found or not v_to.active then raise exception 'الموجه الجديد غير موجود أو غير نشط'; end if;
  select count(*) into v_bad from public.schools where id = any(p_school_ids) and stage like 'ثانوي%';
  if v_bad > 0 then raise exception 'مدارس الثانوي تُسند بالمادة من شاشة إدخال بيانات المدارس، لا من هنا'; end if;
  select count(*) into v_bad from public.schools where id = any(p_school_ids) and not private.can_access_stage(stage);
  if v_bad > 0 then raise exception 'مدرسة خارج نطاق مراحلك'; end if;
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
      raise exception 'الموجه % غير مسجّل في مرحلة «%» — يسجّله مدير النظام أولًا من شاشة الموجهين', v_to.full_name, v_stage;
    end if;
    update public.schools set supervisor_id = p_to_supervisor
     where id = any(p_school_ids) and supervisor_id is distinct from p_to_supervisor;
    get diagnostics v_n = row_count;
    insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
    values (v_actor, 'stage_coordinator', 'gc_move_schools', 'schools', p_to_supervisor::text,
      jsonb_build_object('schools', v_rows),
      jsonb_build_object('to_supervisor', p_to_supervisor, 'to_name', v_to.full_name, 'moved', v_n, 'reason', nullif(p_reason, '')));
  end if;
  return jsonb_build_object('to_name', v_to.full_name, 'applied', p_apply, 'moved', v_n, 'schools', v_rows);
end $$;

revoke all on function public.my_coordinator_scope() from public, anon;
revoke all on function public.admin_set_general_coordinator(uuid, boolean, text) from public, anon;
revoke all on function public.admin_general_coordinators() from public, anon;
revoke all on function public.coordinator_move_schools(uuid[], uuid, boolean, text) from public, anon;
revoke all on function private.is_general_coordinator(uuid) from public, anon;
grant execute on function public.my_coordinator_scope() to authenticated;
grant execute on function public.admin_set_general_coordinator(uuid, boolean, text) to authenticated;
grant execute on function public.admin_general_coordinators() to authenticated;
grant execute on function public.coordinator_move_schools(uuid[], uuid, boolean, text) to authenticated;
grant execute on function private.is_general_coordinator(uuid) to authenticated;
