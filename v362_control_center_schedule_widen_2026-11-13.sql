-- v362 مركز التحكم — الاقتراح ٣ (بقرار المستخدم «الثلاثه»):
--  (1) توسيع محكوم مغلق افتراضيًا: منسق المرحلة ينشئ حساب دخول لمعلم مسجّل في مدرسة من مراحله ويعيد تعيين كلمة مرور حساب معلم (يُلزم بتغييرها)
--  (2) الجدولة: تجميد التعديل في فترة (يُحسب لحظيًا في cap_allowed) + جدولة مفتاحي بوابة المعلمين (pg_cron كل 5 دقائق)
--  (3) ملخص أسبوعي لمدير النظام داخل البرنامج (pg_cron صباح السبت)
-- الاسترجاع: rollback_v362_control_center_schedule_widen_2026-11-13.sql

-- نسخة احتياطية من الدوال التي تُستبدل
create table if not exists private.v362_backup_functions(name text primary key, def text not null, saved_at timestamptz not null default now());
insert into private.v362_backup_functions(name, def)
select x.n, pg_get_functiondef(x.n::regprocedure) from (values
 ('private.cap_allowed(text)'), ('private.cap_allowed_for(uuid,text,text)'), ('public.my_capabilities()'),
 ('public.admin_permission_matrix()'),
 ('public.service_link_created_system_user_atomic(uuid,uuid,public.app_role,text,text,text,public.app_role,uuid,text,text,text,date,public.work_type)')) x(n)
on conflict (name) do nothing;
revoke all on private.v362_backup_functions from public, anon, authenticated;

-- ═════ (1) نوع الإجراء + إجراء التوسيع ═════
alter table public.permission_capabilities add column if not exists kind text not null default 'restrict';
do $k$ begin
  if not exists(select 1 from pg_constraint where conname = 'permission_capabilities_kind_chk') then
    alter table public.permission_capabilities add constraint permission_capabilities_kind_chk check (kind in ('restrict','widen'));
  end if;
end $k$;
insert into public.permission_capabilities(code, label, description, sort, kind) values
 ('widen.coord_accounts', 'حسابات دخول معلمي المرحلة',
  'منسق المرحلة ينشئ حساب دخول لمعلم مسجّل بلا حساب في مدرسة من مراحله، ويعيد تعيين كلمة مرور حساب معلم (معلم/حساب المدرسة فقط) ويُلزمه بتغييرها عند الدخول',
  900, 'widen')
on conflict (code) do nothing;
insert into public.permission_rules(capability, role, allowed, updated_at)
values ('widen.coord_accounts', 'stage_coordinator', false, now())
on conflict (capability, role) do nothing;

-- ═════ (2أ) فترات التجميد ═════
create table if not exists public.permission_freezes(
  id uuid primary key default gen_random_uuid(),
  capabilities text[],            -- فارغ = كل الإجراءات
  roles text[],                   -- فارغ = كل الأدوار عدا مدير النظام
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  created_by uuid,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid,
  constraint permission_freezes_range check (ends_at > starts_at));
alter table public.permission_freezes enable row level security;
revoke all on public.permission_freezes from public, anon, authenticated;
create index if not exists permission_freezes_open_idx on public.permission_freezes(ends_at) where cancelled_at is null;

-- قرار الصلاحية: تجميد ساري ← منع؛ ثم استثناء الشخص؛ ثم قاعدة الدور؛ وإن لم توجد قاعدة: الإجراء العادي مسموح والتوسيع ممنوع
create or replace function private.cap_allowed_for(p_profile uuid, p_role text, p_cap text)
returns boolean language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_g boolean; v_kind text;
begin
  if p_profile is null or p_role is null or p_role = 'admin' then return true; end if;
  if exists(select 1 from public.permission_freezes f
             where f.cancelled_at is null and now() >= f.starts_at and now() < f.ends_at
               and (f.capabilities is null or p_cap = any(f.capabilities))
               and (f.roles is null or p_role = any(f.roles))) then
    return false;
  end if;
  select g.allowed into v_g from public.permission_grants g
   where g.profile_id = p_profile and g.capability = p_cap and g.revoked_at is null
     and now() >= g.starts_at and (g.expires_at is null or now() < g.expires_at)
   order by g.created_at desc limit 1;
  if found then return v_g; end if;
  select c.kind into v_kind from public.permission_capabilities c where c.code = p_cap;
  return coalesce((select r.allowed from public.permission_rules r where r.capability = p_cap and r.role::text = p_role),
                  coalesce(v_kind, 'restrict') <> 'widen');
end $fn$;

create or replace function private.cap_allowed(p_cap text)
returns boolean language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_role public.app_role;
begin
  if auth.uid() is null then return true; end if;
  v_role := private.current_app_role();
  if v_role is null or v_role = 'admin' then return true; end if;
  return private.cap_allowed_for(auth.uid(), v_role::text, p_cap);
end $fn$;

-- ما الممنوع وما المُوسَّع للمستخدم الحالي + التجميد الساري (للشريط في الواجهة)
create or replace function public.my_capabilities()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_role text := private.current_app_role()::text; v_fz jsonb;
begin
  if auth.uid() is null then return jsonb_build_object('role', null, 'blocked', '[]'::jsonb, 'widened', '[]'::jsonb, 'freeze', null); end if;
  if v_role is distinct from 'admin' then
    select jsonb_build_object('ends_at', f.ends_at, 'reason', f.reason, 'all', f.capabilities is null) into v_fz
      from public.permission_freezes f
     where f.cancelled_at is null and now() >= f.starts_at and now() < f.ends_at and (f.roles is null or v_role = any(f.roles))
     order by f.ends_at desc limit 1;
  end if;
  return jsonb_build_object('role', v_role,
    'blocked', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'label', c.label) order by c.sort)
                           from public.permission_capabilities c
                          where c.kind = 'restrict' and not private.cap_allowed_for(auth.uid(), v_role, c.code)), '[]'::jsonb),
    'widened', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'label', c.label) order by c.sort)
                           from public.permission_capabilities c
                          where c.kind = 'widen' and v_role is distinct from 'admin' and private.cap_allowed_for(auth.uid(), v_role, c.code)), '[]'::jsonb),
    'freeze', v_fz);
end $fn$;

create or replace function public.admin_permission_matrix()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
begin
  perform private.v356_require_admin();
  return jsonb_build_object(
    'capabilities', (select coalesce(jsonb_agg(jsonb_build_object('code',code,'label',label,'description',description,'kind',kind) order by sort), '[]'::jsonb) from public.permission_capabilities),
    'rules', (select coalesce(jsonb_agg(jsonb_build_object('cap',capability,'role',role::text,'allowed',allowed,'updated_at',updated_at)), '[]'::jsonb) from public.permission_rules),
    'accounts', (select coalesce(jsonb_object_agg(role, c), '{}'::jsonb) from (select ur.role::text role, count(*) c from public.user_roles ur join public.profiles p on p.id = ur.profile_id and p.is_active where ur.is_active group by ur.role) x));
end $fn$;

-- ربط الحساب المنشأ: فرع منسق المرحلة (معلم مسجّل بلا حساب في مدرسة من مراحله، وبإذن التوسيع) — استبدال نصي مرة واحدة لكل موضع
do $m$
declare d text; n text;
  k1 text := $s$            or (p_actor_role='senior_teacher' and p_role='teacher');$s$;
  k2 text := $s$  elsif p_actor_role='senior_teacher' and p_role='teacher' then$s$;
begin
  select pg_get_functiondef('public.service_link_created_system_user_atomic(uuid,uuid,public.app_role,text,text,text,public.app_role,uuid,text,text,text,date,public.work_type)'::regprocedure) into d;
  if (length(d) - length(replace(d, k1, ''))) / length(k1) <> 1 then raise exception 'v362: نص v_allowed غير مطابق'; end if;
  if (length(d) - length(replace(d, k2, ''))) / length(k2) <> 1 then raise exception 'v362: نص فحص النطاق غير مطابق'; end if;
  n := replace(d, k1, $s$            or (p_actor_role='senior_teacher' and p_role='teacher')
            or (p_actor_role='stage_coordinator' and p_role='teacher' and private.cap_allowed_for(p_actor_id,'stage_coordinator','widen.coord_accounts'));$s$);
  n := replace(n, k2, $s$  elsif p_actor_role='stage_coordinator' and p_role='teacher' then
    if not exists(select 1 from public.schools sc
                   join public.stage_coordinator_assignments sca on sca.stage = sc.stage and sca.active
                   join public.supervisors s on s.id = sca.supervisor_id and s.active
                  where sc.id = p_school_id and s.profile_id = p_actor_id) then
      raise exception 'المدرسة ليست ضمن مراحلك';
    end if;
    if not exists(select 1 from public.teacher_records tr
                   where tr.civil_id = btrim(p_civil_id) and tr.active and tr.profile_id is null and tr.home_school_id = p_school_id) then
      raise exception 'يُنشأ حساب الدخول لمعلم مسجّل في البرنامج بمدرسته الأصلية وبلا حساب فقط';
    end if;
$s$ || k2);
  execute n;
end $m$;

-- فحص إعادة كلمة المرور بيد المنسق (لدالة الحافة فقط): null = مسموح، وإلا السبب
create or replace function public.service_coord_account_check(p_actor uuid, p_target uuid)
returns text language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_stage text;
begin
  if p_actor is null or p_target is null then return 'بيانات ناقصة'; end if;
  if p_actor = p_target then return 'غيّر كلمة مرورك من «بياناتي»'; end if;
  if not exists(select 1 from public.profiles p where p.id = p_actor and p.is_active) then return 'الحساب غير مفعل'; end if;
  if not exists(select 1 from public.user_roles ur where ur.profile_id = p_actor and ur.role = 'stage_coordinator' and ur.is_active) then return 'دور منسق المرحلة غير نشط'; end if;
  if not private.cap_allowed_for(p_actor, 'stage_coordinator', 'widen.coord_accounts') then
    return 'لم تُفتح لك هذه الصلاحية من مركز التحكم: حسابات دخول معلمي المرحلة';
  end if;
  if not exists(select 1 from public.profiles p where p.id = p_target and p.is_active) then return 'حساب المعلم معطل؛ يفعّله مدير النظام'; end if;
  if exists(select 1 from public.user_roles ur where ur.profile_id = p_target and ur.is_active and ur.role not in ('teacher','senior_teacher')) then
    return 'هذا الحساب له دور غير المعلم؛ يعيد كلمة مروره مدير النظام فقط';
  end if;
  select sc.stage into v_stage from public.teacher_records tr join public.schools sc on sc.id = tr.home_school_id
   where tr.profile_id = p_target and tr.active limit 1;
  if v_stage is null then return 'الحساب ليس لمعلم مسجّل بمدرسة أصلية'; end if;
  if not exists(select 1 from public.stage_coordinator_assignments sca join public.supervisors s on s.id = sca.supervisor_id and s.active
                 where s.profile_id = p_actor and sca.active and sca.stage = v_stage) then
    return 'المعلم خارج مراحلك';
  end if;
  return null;
end $fn$;
revoke all on function public.service_coord_account_check(uuid,uuid) from public, anon, authenticated;
grant execute on function public.service_coord_account_check(uuid,uuid) to service_role;

-- ═════ (2ب) جدولة مفتاحي البوابة ═════
create table if not exists public.scheduled_flag_changes(
  id uuid primary key default gen_random_uuid(),
  flag text not null check (flag in ('editing_open','timetable_open')),
  value boolean not null,
  run_at timestamptz not null,
  reason text,
  created_by uuid,
  created_at timestamptz not null default now(),
  done_at timestamptz,
  result text,
  cancelled_at timestamptz,
  cancelled_by uuid);
alter table public.scheduled_flag_changes enable row level security;
revoke all on public.scheduled_flag_changes from public, anon, authenticated;
create index if not exists scheduled_flag_changes_due_idx on public.scheduled_flag_changes(run_at) where done_at is null and cancelled_at is null;

create or replace function private.run_scheduled_flags()
returns int language plpgsql security definer set search_path = public, pg_temp as $fn$
declare r record; v_old boolean; n int := 0;
begin
  for r in select * from public.scheduled_flag_changes
            where done_at is null and cancelled_at is null and run_at <= now()
            order by run_at, created_at for update skip locked loop
    if r.flag = 'editing_open' then
      select editing_open into v_old from public.teacher_portal_settings where id = 1;
      update public.teacher_portal_settings set editing_open = r.value, updated_at = now() where id = 1;
    else
      select timetable_open into v_old from public.teacher_portal_settings where id = 1;
      update public.teacher_portal_settings set timetable_open = r.value, updated_at = now() where id = 1;
    end if;
    update public.scheduled_flag_changes set done_at = now(), result = 'ok' where id = r.id;
    insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
    values (r.created_by, 'admin', 'cc_flag_scheduled_run', 'teacher_portal_settings', r.flag,
            jsonb_build_object(r.flag, v_old), jsonb_build_object(r.flag, r.value, 'schedule_id', r.id, 'run_at', r.run_at, 'reason', r.reason));
    n := n + 1;
  end loop;
  return n;
end $fn$;
revoke all on function private.run_scheduled_flags() from public, anon, authenticated;

create or replace function public.admin_flag_schedule_add(p_flag text, p_value boolean, p_run_at timestamptz, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_id uuid;
begin
  if p_flag not in ('editing_open','timetable_open') then raise exception 'مفتاح غير معروف'; end if;
  if p_value is null or p_run_at is null then raise exception 'حدّد الحالة والموعد'; end if;
  if p_run_at <= now() then raise exception 'الموعد يجب أن يكون في المستقبل'; end if;
  if p_run_at > now() + interval '180 days' then raise exception 'الموعد أبعد من 180 يومًا'; end if;
  insert into public.scheduled_flag_changes(flag, value, run_at, reason, created_by)
  values (p_flag, p_value, p_run_at, nullif(btrim(coalesce(p_reason,'')),''), v_actor) returning id into v_id;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_flag_schedule_add', 'scheduled_flag_changes', v_id::text, null,
          jsonb_build_object('flag', p_flag, 'value', p_value, 'run_at', p_run_at, 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true, 'id', v_id);
end $fn$;

create or replace function public.admin_flag_schedule_cancel(p_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); r record;
begin
  update public.scheduled_flag_changes set cancelled_at = now(), cancelled_by = v_actor
   where id = p_id and done_at is null and cancelled_at is null returning * into r;
  if not found then raise exception 'الموعد غير موجود أو نُفّذ أو أُلغي'; end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_flag_schedule_cancel', 'scheduled_flag_changes', p_id::text,
          jsonb_build_object('flag', r.flag, 'value', r.value, 'run_at', r.run_at), jsonb_build_object('reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true);
end $fn$;

create or replace function public.admin_freeze_add(p_starts timestamptz, p_ends timestamptz, p_caps text[] default null, p_roles text[] default null, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_id uuid; v_s timestamptz := coalesce(p_starts, now());
  v_caps text[] := case when coalesce(cardinality(p_caps),0) = 0 then null else p_caps end;
  v_roles text[] := case when coalesce(cardinality(p_roles),0) = 0 then null else p_roles end;
begin
  if p_ends is null or p_ends <= v_s then raise exception 'نهاية التجميد يجب أن تكون بعد بدايته'; end if;
  if p_ends <= now() then raise exception 'نهاية التجميد في الماضي'; end if;
  if p_ends - v_s > interval '60 days' then raise exception 'أقصى مدة للتجميد 60 يومًا'; end if;
  if v_caps is not null and exists(select 1 from unnest(v_caps) c where c not in (select code from public.permission_capabilities)) then raise exception 'إجراء غير معروف'; end if;
  if v_roles is not null and exists(select 1 from unnest(v_roles) r where r not in ('stage_coordinator','supervisor','senior_teacher','school_manager','teacher','first_supervisor')) then
    raise exception 'دور غير مسموح (مدير النظام لا يُجمَّد)';
  end if;
  insert into public.permission_freezes(capabilities, roles, starts_at, ends_at, reason, created_by)
  values (v_caps, v_roles, v_s, p_ends, nullif(btrim(coalesce(p_reason,'')),''), v_actor) returning id into v_id;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_freeze_add', 'permission_freezes', v_id::text, null,
          jsonb_build_object('capabilities', v_caps, 'roles', v_roles, 'starts_at', v_s, 'ends_at', p_ends, 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true, 'id', v_id);
end $fn$;

create or replace function public.admin_freeze_cancel(p_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); r record;
begin
  update public.permission_freezes set cancelled_at = now(), cancelled_by = v_actor
   where id = p_id and cancelled_at is null and ends_at > now() returning * into r;
  if not found then raise exception 'التجميد غير موجود أو انتهى أو أُلغي'; end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_freeze_cancel', 'permission_freezes', p_id::text,
          jsonb_build_object('capabilities', r.capabilities, 'roles', r.roles, 'starts_at', r.starts_at, 'ends_at', r.ends_at),
          jsonb_build_object('reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true);
end $fn$;

-- قائمة الجدولة والتجميد (تنفّذ أولًا أي موعد فات احتياطًا إن تأخرت المهمة المجدولة)
create or replace function public.admin_schedule_list()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_ran int;
begin
  v_ran := private.run_scheduled_flags();
  return jsonb_build_object(
    'ran_now', v_ran,
    'settings', (select jsonb_build_object('editing_open', editing_open, 'timetable_open', timetable_open) from public.teacher_portal_settings where id = 1),
    'freezes', coalesce((select jsonb_agg(x order by x.ord, x.starts_at desc) from (
        select f.id, f.capabilities, f.roles, f.starts_at, f.ends_at, f.reason, f.created_at, f.cancelled_at,
               pc.full_name created_by_name,
               case when f.cancelled_at is not null then 'cancelled' when now() >= f.ends_at then 'ended' when now() >= f.starts_at then 'active' else 'upcoming' end status,
               case when f.cancelled_at is null and now() < f.ends_at then 0 else 1 end ord
          from public.permission_freezes f left join public.profiles pc on pc.id = f.created_by
         where (f.cancelled_at is null and now() < f.ends_at) or f.created_at > now() - interval '60 days'
         order by f.created_at desc limit 60) x), '[]'::jsonb),
    'flags', coalesce((select jsonb_agg(x order by x.ord, x.run_at desc) from (
        select s.id, s.flag, s.value, s.run_at, s.reason, s.created_at, s.done_at, s.result, s.cancelled_at,
               pc.full_name created_by_name,
               case when s.cancelled_at is not null then 'cancelled' when s.done_at is not null then 'done' else 'pending' end status,
               case when s.done_at is null and s.cancelled_at is null then 0 else 1 end ord
          from public.scheduled_flag_changes s left join public.profiles pc on pc.id = s.created_by
         where (s.done_at is null and s.cancelled_at is null) or s.created_at > now() - interval '60 days'
         order by s.created_at desc limit 60) x), '[]'::jsonb),
    'cron', jsonb_build_object(
       'flags_job', exists(select 1 from cron.job where jobname = 'v362-scheduled-flags' and active),
       'digest_job', exists(select 1 from cron.job where jobname = 'v362-admin-digest' and active),
       'last_flags_run', (select max(d.end_time) from cron.job_run_details d join cron.job j on j.jobid = d.jobid where j.jobname = 'v362-scheduled-flags')));
end $fn$;

-- ═════ (3) الملخص الأسبوعي ═════
create table if not exists public.admin_digests(
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  period_from timestamptz not null,
  period_to timestamptz not null,
  data jsonb not null,
  seen_at timestamptz,
  seen_by uuid);
alter table public.admin_digests enable row level security;
revoke all on public.admin_digests from public, anon, authenticated;

-- يحسب إشارات الخطر بنفس دالة مركز التحكم (بهوية مدير النظام محليًا داخل المعاملة ثم يعيدها) + أرقام الأسبوع
create or replace function private.make_admin_digest()
returns bigint language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_admin uuid; v_cc jsonb; v_from timestamptz := now() - interval '7 days'; v_to timestamptz := now(); v jsonb; v_id bigint;
  v_claims text := current_setting('request.jwt.claims', true); v_headers text := current_setting('request.headers', true);
begin
  select ur.profile_id into v_admin from public.user_roles ur join public.profiles p on p.id = ur.profile_id and p.is_active
   where ur.role = 'admin' and ur.is_active order by p.created_at limit 1;
  if v_admin is null then return null; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  perform set_config('request.headers', json_build_object('x-app-role', 'admin')::text, true);
  v_cc := public.admin_control_center();
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.headers', coalesce(v_headers, ''), true);
  v := jsonb_build_object(
    'signals', coalesce((select jsonb_agg(jsonb_build_object('code', s->>'code', 'title', s->>'title', 'level', s->>'level',
                 'count', jsonb_array_length(coalesce(s->'items', '[]'::jsonb)),
                 'items', coalesce((select jsonb_agg(i) from (select i from jsonb_array_elements(coalesce(s->'items', '[]'::jsonb)) i limit 15) z), '[]'::jsonb)))
               from jsonb_array_elements(coalesce(v_cc->'signals', '[]'::jsonb)) s), '[]'::jsonb),
    'stats', v_cc->'stats',
    'week', jsonb_build_object(
       'sessions', (select count(*) from public.user_access_log where started_at >= v_from),
       'users', (select count(distinct profile_id) from public.user_access_log where started_at >= v_from),
       'login_failures', (select count(*) from public.login_failures where created_at >= v_from),
       'portal_failures', (select count(*) from public.teacher_portal_attempts where created_at >= v_from and not coalesce(ok, false)),
       'actions', (select count(*) from public.audit_log where created_at >= v_from),
       'cc_actions', (select count(*) from public.audit_log where created_at >= v_from and action like 'cc\_%'),
       'top_actors', coalesce((select jsonb_agg(jsonb_build_object('name', x.name, 'n', x.n) order by x.n desc) from (
            select coalesce(p.full_name, '—') name, count(*) n from public.audit_log a left join public.profiles p on p.id = a.actor_profile_id
             where a.created_at >= v_from and a.actor_profile_id is not null group by p.full_name order by count(*) desc limit 5) x), '[]'::jsonb)),
    'controls', jsonb_build_object(
       'blocked_rules', (select count(*) from public.permission_rules r join public.permission_capabilities c on c.code = r.capability where c.kind = 'restrict' and not r.allowed),
       'widened_rules', (select count(*) from public.permission_rules r join public.permission_capabilities c on c.code = r.capability where c.kind = 'widen' and r.allowed),
       'grants_active', (select count(*) from public.permission_grants g where g.revoked_at is null and now() >= g.starts_at and (g.expires_at is null or now() < g.expires_at)),
       'grants_expiring_7d', (select count(*) from public.permission_grants g where g.revoked_at is null and g.expires_at between now() and now() + interval '7 days'),
       'freezes_open', (select count(*) from public.permission_freezes f where f.cancelled_at is null and now() < f.ends_at),
       'flags_pending', (select count(*) from public.scheduled_flag_changes s where s.done_at is null and s.cancelled_at is null),
       'editing_open', (select editing_open from public.teacher_portal_settings where id = 1),
       'timetable_open', (select timetable_open from public.teacher_portal_settings where id = 1)));
  insert into public.admin_digests(period_from, period_to, data) values (v_from, v_to, v) returning id into v_id;
  return v_id;
end $fn$;
revoke all on function private.make_admin_digest() from public, anon, authenticated;

create or replace function public.admin_digest_latest()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin();
begin
  return (select jsonb_build_object('id', d.id, 'created_at', d.created_at, 'period_from', d.period_from, 'period_to', d.period_to,
                 'data', d.data, 'seen_at', d.seen_at, 'seen_by_name', p.full_name,
                 'unseen', (select count(*) from public.admin_digests x where x.seen_at is null))
            from public.admin_digests d left join public.profiles p on p.id = d.seen_by
           order by d.id desc limit 1);
end $fn$;

create or replace function public.admin_digest_seen(p_id bigint)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_n int;
begin
  update public.admin_digests set seen_at = now(), seen_by = v_actor where id <= p_id and seen_at is null;
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'marked', v_n);
end $fn$;

create or replace function public.admin_digest_run()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_id bigint;
begin
  v_id := private.make_admin_digest();
  return jsonb_build_object('ok', true, 'id', v_id);
end $fn$;

do $g$
declare f text;
begin
  foreach f in array array['public.admin_flag_schedule_add(text,boolean,timestamptz,text)','public.admin_flag_schedule_cancel(uuid,text)',
    'public.admin_freeze_add(timestamptz,timestamptz,text[],text[],text)','public.admin_freeze_cancel(uuid,text)','public.admin_schedule_list()',
    'public.admin_digest_latest()','public.admin_digest_seen(bigint)','public.admin_digest_run()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $g$;

-- ═════ المهام المجدولة (pg_cron) ═════
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
select cron.schedule('v362-scheduled-flags', '*/5 * * * *', 'select private.run_scheduled_flags()');
select cron.schedule('v362-admin-digest', '7 4 * * 6', 'select private.make_admin_digest()');  -- السبت 06:07 بتوقيت القاهرة
select private.make_admin_digest();  -- أول ملخص الآن
