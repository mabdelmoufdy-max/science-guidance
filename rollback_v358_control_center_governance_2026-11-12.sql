-- استرجاع v358: يزيل الاستثناءات المؤقتة والمراجعة و«اعرض كمستخدم» والتراجع، ويعيد cap_allowed ونقل المدارس كما في v357/v356
drop function if exists public.admin_revert_action(bigint,text);
drop function if exists public.admin_view_as(uuid,text);
drop function if exists public.admin_access_review_decide(uuid,text,text,text);
drop function if exists public.admin_access_review_list();
drop function if exists public.admin_grants_list();
drop function if exists public.admin_grant_revoke(uuid,text);
drop function if exists public.admin_grant_add(uuid,text,boolean,int,text);
create or replace function private.cap_allowed(p_cap text) returns boolean
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_role public.app_role;
begin
  if auth.uid() is null then return true; end if;
  v_role := private.current_app_role();
  if v_role is null or v_role = 'admin' then return true; end if;
  return coalesce((select allowed from public.permission_rules where capability = p_cap and role = v_role), true);
end $fn$;
drop table if exists public.access_reviews;
drop table if exists public.permission_grants;
-- admin_move_schools: نسخة v358 (فحص المرحلة قبل التطبيق) تبقى؛ لإرجاع نسخة v356 أعد تشغيل جزئها من v356_control_center_actions_2026-11-12.sql
