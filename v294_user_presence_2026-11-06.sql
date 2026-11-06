-- v294_user_presence (2026-11-06): «المتصلون الآن» لمدير النظام.
-- جدول نبضة اتصال (سطر واحد لكل حساب، يُحدَّث ولا يتراكم) + دالتان:
--   presence_ping()        : يستدعيها البرنامج كل دقيقة لأي مستخدم مسجل (الدور النشط من x-app-role).
--   admin_online_users()   : لمدير النظام فقط (الدور النشط admin) — كل الحسابات النشطة مع حالة الاتصال.
-- لا يمس أي جدول أو دالة قائمة. لا قراءة ولا كتابة مباشرة على الجدول لأي دور.
-- متصل = آخر نبضة خلال 3 دقائق. بلا مفتاح أجنبي حتى لا يعطّل حذف حساب.

create table if not exists public.user_presence (
  profile_id uuid primary key,
  active_role public.app_role,
  session_started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
alter table public.user_presence enable row level security;
revoke all on public.user_presence from anon, authenticated;
comment on table public.user_presence is 'v294: نبضة اتصال المستخدمين (المتصلون الآن لمدير النظام). سطر لكل حساب.';

create or replace function public.presence_ping()
returns void
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
begin
  if auth.uid() is null then return; end if;
  insert into public.user_presence as p (profile_id, active_role, session_started_at, last_seen_at)
  select auth.uid(), private.current_app_role(), now(), now()
  where exists (select 1 from public.profiles pr where pr.id = auth.uid() and pr.is_active)
  on conflict (profile_id) do update
    set active_role = excluded.active_role,
        session_started_at = case when p.last_seen_at < now() - interval '5 minutes' then now() else p.session_started_at end,
        last_seen_at = now()
  where p.last_seen_at < now() - interval '20 seconds'
     or p.active_role is distinct from excluded.active_role;
end
$function$;

create or replace function public.admin_online_users()
returns table (
  profile_id uuid,
  full_name text,
  roles text[],
  active_role public.app_role,
  online boolean,
  session_started_at timestamptz,
  last_seen_at timestamptz,
  last_sign_in_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
#variable_conflict use_column
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return query
  select pr.id,
         pr.full_name,
         array(select ur.role::text from public.user_roles ur
               where ur.profile_id = pr.id and ur.is_active order by ur.role),
         up.active_role,
         coalesce(up.last_seen_at > now() - interval '3 minutes', false),
         up.session_started_at,
         up.last_seen_at,
         au.last_sign_in_at
  from public.profiles pr
  left join public.user_presence up on up.profile_id = pr.id
  left join auth.users au on au.id = pr.id
  where pr.is_active
  order by coalesce(up.last_seen_at > now() - interval '3 minutes', false) desc,
           up.last_seen_at desc nulls last,
           pr.full_name;
end
$function$;

revoke all on function public.presence_ping() from public, anon;
revoke all on function public.admin_online_users() from public, anon;
grant execute on function public.presence_ping() to authenticated;
grant execute on function public.admin_online_users() to authenticated;
