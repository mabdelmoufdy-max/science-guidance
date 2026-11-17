-- v399: عدد الإجراءات لكل مستخدم في «سجل الدخول» (مدير النظام فقط) — دالة قراءة جديدة بلا أي تعديل في الجداول.
-- يعدّ سجلات audit_log التي actor_profile_id فيها = المستخدم في الفترة [p_from, p_to). (إجراءات معلمي بوابة المعلمين بلا حساب فلا تُنسب لأحد.)
-- طُبّق عبر apply_migration بعد تجربة جافة (المدير 8 مستخدمين/418 إجراءً مطابقة للعدّ المباشر؛ المنسق والزائر «غير مصرح»).
create or replace function public.admin_access_actions(p_from timestamptz, p_to timestamptz)
returns table (profile_id uuid, actions bigint)
language plpgsql stable security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
#variable_conflict use_column
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return query
  select a.actor_profile_id, count(*)::bigint
  from public.audit_log a
  where a.created_at >= p_from and a.created_at < p_to and a.actor_profile_id is not null
  group by a.actor_profile_id;
end
$function$;
revoke all on function public.admin_access_actions(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_access_actions(timestamptz, timestamptz) to authenticated;
