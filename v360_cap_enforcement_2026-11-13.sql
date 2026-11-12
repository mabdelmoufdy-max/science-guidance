-- v360: فرض مصفوفة الصلاحيات في كل الطرق + «صلاحياتي» للواجهة
-- 1) إجراء جديد في المصفوفة: إنشاء حساب دخول (تفحصه دالة الحافة create-system-user)
insert into public.permission_capabilities(code, label, description, sort)
values ('account.create','إنشاء حساب دخول','إنشاء حساب دخول لمعلم أو مشرف مادة',130)
on conflict (code) do nothing;
insert into public.permission_rules(capability, role, allowed)
select 'account.create', r.role, true
from (values ('stage_coordinator'::public.app_role),('supervisor'),('senior_teacher'),('school_manager'),('teacher'),('first_supervisor')) r(role)
on conflict do nothing;

-- 2) الفحص بهوية صريحة (نفس منطق cap_allowed: الاستثناء الساري للشخص ثم قاعدة الدور؛ المدير دائمًا مسموح)
create or replace function private.cap_allowed_for(p_profile uuid, p_role text, p_cap text) returns boolean
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_g boolean;
begin
  if p_profile is null or p_role is null or p_role = 'admin' then return true; end if;
  select g.allowed into v_g from public.permission_grants g
   where g.profile_id = p_profile and g.capability = p_cap and g.revoked_at is null
     and now() >= g.starts_at and (g.expires_at is null or now() < g.expires_at)
   order by g.created_at desc limit 1;
  if found then return v_g; end if;
  return coalesce((select r.allowed from public.permission_rules r where r.capability = p_cap and r.role::text = p_role), true);
end $fn$;
revoke all on function private.cap_allowed_for(uuid,text,text) from public, anon, authenticated;

-- 3) لدوال الحافة فقط (مفتاح الخدمة): لا ينفذها المستخدمون ولا الزوار
create or replace function public.service_cap_allowed(p_profile uuid, p_role text, p_cap text) returns boolean
language sql stable security definer set search_path = public, pg_temp as $fn$
  select private.cap_allowed_for(p_profile, p_role, p_cap);
$fn$;
revoke all on function public.service_cap_allowed(uuid,text,text) from public, anon, authenticated;
grant execute on function public.service_cap_allowed(uuid,text,text) to service_role;

-- 4) «صلاحياتي»: الإجراءات الممنوعة على المستخدم الحالي بدوره النشط (لتعطيل الأزرار في الواجهة)
create or replace function public.my_capabilities() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_role text := private.current_app_role()::text;
begin
  if auth.uid() is null then return jsonb_build_object('role', null, 'blocked', '[]'::jsonb); end if;
  return jsonb_build_object('role', v_role, 'blocked', coalesce((
    select jsonb_agg(jsonb_build_object('code', c.code, 'label', c.label) order by c.sort)
    from public.permission_capabilities c
    where not private.cap_allowed_for(auth.uid(), v_role, c.code)), '[]'::jsonb));
end $fn$;
revoke all on function public.my_capabilities() from public, anon;
grant execute on function public.my_capabilities() to authenticated;

-- 5) admin_control_center: هل للحساب سجل موجه/معلم (لإخفاء خيارات لا تنطبق في نافذة الأدوار) — استبدال نصي مرة واحدة
do $m$
declare d text; k text := $s$'home_school', home_school$s$; n text;
begin
  select pg_get_functiondef('public.admin_control_center()'::regprocedure) into d;
  if (length(d) - length(replace(d, k, ''))) / length(k) <> 1 then raise exception 'v360: نص admin_control_center غير مطابق'; end if;
  n := replace(d, k, k || $s$, 'has_sup', sup_id is not null, 'has_teacher', teacher_id is not null$s$);
  execute n;
end $m$;
