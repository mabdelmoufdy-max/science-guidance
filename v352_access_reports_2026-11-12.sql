-- v352_access_reports: سجل الدخول على البرنامج + محاولات الدخول المرفوضة + تقريران لمدير النظام.
-- لا يمس أي بيانات تعليمية. الاسترجاع: rollback_v352_access_reports_2026-11-12.sql

create schema if not exists private;
create table if not exists private.v352_backup_functions as
select p.oid::regprocedure::text as sig, pg_get_functiondef(p.oid) as def, now() as saved_at
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where (n.nspname = 'public' and p.proname = 'presence_ping')
   or (n.nspname = 'private' and p.proname = 'tp_check');

-- 1) سجل الجلسات
create table if not exists public.user_access_log (
  id bigint generated always as identity primary key,
  profile_id uuid not null,
  active_role public.app_role,
  device text,
  started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index if not exists user_access_log_started_idx on public.user_access_log (started_at);
create index if not exists user_access_log_profile_idx on public.user_access_log (profile_id, started_at desc);
alter table public.user_access_log enable row level security;
revoke all on public.user_access_log from anon, authenticated, public;

-- 2) محاولات الدخول الفاشلة على شاشة الدخول
create table if not exists public.login_failures (
  id bigint generated always as identity primary key,
  identifier text not null,
  reason text not null check (reason in ('bad_credentials','inactive')),
  profile_id uuid,
  device text,
  created_at timestamptz not null default now()
);
create index if not exists login_failures_created_idx on public.login_failures (created_at);
alter table public.login_failures enable row level security;
revoke all on public.login_failures from anon, authenticated, public;

create or replace function private.v352_device()
returns text language plpgsql stable
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare ua text;
begin
  begin
    ua := coalesce(nullif(current_setting('request.headers', true), '')::jsonb ->> 'user-agent', '');
  exception when others then ua := '';
  end;
  if ua = '' then return null; end if;
  if ua ~* '(mobile|android|iphone|ipad|ipod)' then return 'mobile'; end if;
  return 'desktop';
end
$fn$;
revoke all on function private.v352_device() from public, anon, authenticated;

-- 3) النبضة تسجّل الجلسة (نفس التوقيع؛ العملاء بلا تغيير)
create or replace function public.presence_ping()
returns void
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_prev timestamptz;
  v_role public.app_role;
  v_log bigint;
begin
  if v_uid is null then return; end if;
  if not exists (select 1 from public.profiles pr where pr.id = v_uid and pr.is_active) then return; end if;
  v_role := private.current_app_role();
  select p.last_seen_at into v_prev from public.user_presence p where p.profile_id = v_uid;

  insert into public.user_presence as p (profile_id, active_role, session_started_at, last_seen_at)
  values (v_uid, v_role, now(), now())
  on conflict (profile_id) do update
    set active_role = excluded.active_role,
        session_started_at = case when p.last_seen_at < now() - interval '5 minutes' then now() else p.session_started_at end,
        last_seen_at = now()
  where p.last_seen_at < now() - interval '20 seconds'
     or p.active_role is distinct from excluded.active_role;

  -- سجل الدخول: جلسة جديدة بعد غياب 5 دقائق، وإلا تمديد آخر جلسة
  if v_prev is not null and v_prev >= now() - interval '5 minutes' then
    select l.id into v_log from public.user_access_log l
     where l.profile_id = v_uid and l.last_seen_at >= now() - interval '5 minutes'
     order by l.started_at desc limit 1;
  end if;
  if v_log is null then
    insert into public.user_access_log (profile_id, active_role, device)
    values (v_uid, v_role, private.v352_device());
  else
    update public.user_access_log l
       set last_seen_at = now(), active_role = coalesce(v_role, l.active_role)
     where l.id = v_log and (l.last_seen_at < now() - interval '20 seconds' or l.active_role is distinct from v_role);
  end if;

  -- لا تنظيف تلقائي (بقرار المستخدم «ب» 2026-11-12): السجل صغير، والتنظيف يُضاف لاحقًا إن لزم.
end
$function$;
revoke all on function public.presence_ping() from public, anon;
grant execute on function public.presence_ping() to authenticated;

-- 4) تسجيل محاولة دخول فاشلة (يستدعيها المتصفح قبل تسجيل الدخول)
create or replace function public.log_login_failure(p_identifier text, p_reason text default 'bad_credentials')
returns void
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
declare
  v_id text := left(btrim(translate(coalesce(p_identifier, ''), '٠١٢٣٤٥٦٧٨٩', '0123456789')), 60);
  v_reason text := case when p_reason = 'inactive' then 'inactive' else 'bad_credentials' end;
  v_profile uuid;
begin
  if v_id = '' then return; end if;
  -- حدود حتى لا يُغرق الجدول
  if (select count(*) from public.login_failures where created_at > now() - interval '1 minute') >= 30 then return; end if;
  if (select count(*) from public.login_failures where identifier = v_id and created_at > now() - interval '10 minutes') >= 10 then return; end if;
  select pr.id into v_profile from public.profiles pr where pr.civil_id = v_id limit 1;
  insert into public.login_failures (identifier, reason, profile_id, device)
  values (v_id, v_reason, v_profile, private.v352_device());
end
$function$;
revoke all on function public.log_login_failure(text, text) from public;
grant execute on function public.log_login_failure(text, text) to anon, authenticated;

-- 5) تقرير الدخول (مدير النظام فقط)
create or replace function public.admin_access_report(p_from timestamptz, p_to timestamptz)
returns table (id bigint, profile_id uuid, full_name text, active_role public.app_role, device text,
               started_at timestamptz, last_seen_at timestamptz)
language plpgsql stable security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
#variable_conflict use_column
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return query
  select l.id, l.profile_id, pr.full_name, l.active_role, l.device, l.started_at, l.last_seen_at
  from public.user_access_log l
  left join public.profiles pr on pr.id = l.profile_id
  where l.started_at >= p_from and l.started_at < p_to
  order by l.started_at desc
  limit 5000;
end
$function$;
revoke all on function public.admin_access_report(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_access_report(timestamptz, timestamptz) to authenticated;

-- 6) تقرير المحاولات المرفوضة: شاشة دخول البرنامج + بوابة المعلمين (مدير النظام فقط)
create or replace function public.admin_denied_attempts(p_from timestamptz, p_to timestamptz)
returns table (source text, identifier text, full_name text, reason text, device text, created_at timestamptz)
language plpgsql stable security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
#variable_conflict use_column
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return query
  select x.source, x.identifier, x.full_name, x.reason, x.device, x.created_at from (
    select 'app'::text as source, f.identifier, pr.full_name, f.reason, f.device, f.created_at
    from public.login_failures f
    left join public.profiles pr on pr.id = f.profile_id
    where f.created_at >= p_from and f.created_at < p_to
    union all
    select 'portal'::text, a.civil_id,
           (select t.full_name from public.teacher_records t where t.civil_id = a.civil_id limit 1),
           a.reason, null::text, a.created_at
    from public.teacher_portal_attempts a
    where not a.ok and a.created_at >= p_from and a.created_at < p_to
  ) x
  order by x.created_at desc
  limit 5000;
end
$function$;
revoke all on function public.admin_denied_attempts(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_denied_attempts(timestamptz, timestamptz) to authenticated;

-- 7) محاولات بوابة المعلمين تُحفظ 6 أشهر بدل يومين (نوافذ القفل 15 و10 دقائق بلا تغيير)
do $do$
declare d text; n int;
begin
  select pg_get_functiondef('private.tp_check(text,text)'::regprocedure) into d;
  n := (length(d) - length(replace(d, 'interval ''2 days''', ''))) / length('interval ''2 days''');
  if n <> 1 then raise exception 'v352: توقعت موضعًا واحدًا لمدة الحفظ في tp_check ووجدت %', n; end if;
  execute replace(d, 'interval ''2 days''', 'interval ''6 months''');
end
$do$;
create index if not exists teacher_portal_attempts_created_idx on public.teacher_portal_attempts (created_at);
