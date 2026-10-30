-- v224 (2026-10-30، بطلب المستخدم «ابدأ الحل الدائم لكل شئ موجود عليه x»): النصاب المخفض من واجهة مدير النظام
-- دالة جديدة فقط؛ لا تغيير في بيانات أو سياسات قائمة. الكتابة في teacher_records.weekly_target_override (عمود v176).
-- الاسترجاع: rollback_v224_admin_set_teacher_weekly_target_2026-10-30.sql
create or replace function public.admin_set_teacher_weekly_target(p_teacher_id uuid, p_target integer)
returns integer
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare v_old integer;
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'تعديل النصاب المخفض متاح لمدير النظام فقط';
  end if;
  if p_target is not null and (p_target < 0 or p_target > 40) then
    raise exception 'النصاب المخفض يجب أن يكون بين 0 و40 حصة (أو فارغًا ليُحسب نصاب الدرجة)';
  end if;
  select weekly_target_override into v_old from public.teacher_records where id = p_teacher_id for update;
  if not found then raise exception 'المعلم غير موجود'; end if;
  update public.teacher_records set weekly_target_override = p_target where id = p_teacher_id;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (auth.uid(), 'admin', 'set_weekly_target_override', 'teacher', p_teacher_id::text,
          jsonb_build_object('weekly_target_override', v_old), jsonb_build_object('weekly_target_override', p_target));
  return p_target;
end
$function$;
revoke all on function public.admin_set_teacher_weekly_target(uuid, integer) from public, anon;
grant execute on function public.admin_set_teacher_weekly_target(uuid, integer) to authenticated;
