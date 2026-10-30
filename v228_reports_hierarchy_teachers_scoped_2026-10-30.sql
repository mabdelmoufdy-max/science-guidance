-- v228 (2026-10-30، بطلب المستخدم «نفذ ٣أ»): قائمة المعلمين في get_reports_dataset (hierarchy.teachers) كانت تُرسل كل المعلمين (348 بالرقم القومي)
-- لكل دور (الموجه، المنسق، مشرف المادة) لأن العرض teacher_workload_summary يتجاوز RLS. صارت مقيدة بـ private.can_access_teacher (المدير والموجه الأول: الكل كما كان).
-- تجربة جافة: 17 مستخدمًا 0 مشكلات (بقية البيانات مطابقة، القائمة الجديدة جزء من القديمة، لا معلم في الكشوف/الإسناد يُفقد). بعد التطبيق: 12 مستخدمًا 0 معلم خارج النطاق.
-- الاسترجاع: rollback_v228_reports_hierarchy_teachers_scoped_2026-10-30.sql
do $mig$
declare d text;
  old_where text := E'      from public.teacher_workload_summary w\n    ),''[]''::jsonb)';
  new_where text := E'      from public.teacher_workload_summary w\n      where (select private.current_app_role()) in (''admin'',''first_supervisor'') or private.can_access_teacher(w.teacher_id)  -- v228: نطاق المستخدم فقط\n    ),''[]''::jsonb)';
begin
  d := pg_get_functiondef('public.get_reports_dataset(uuid)'::regprocedure);
  if (length(d) - length(replace(d, old_where, ''))) / length(old_where) <> 1 then raise exception 'v228: anchor count <> 1'; end if;
  execute replace(d, old_where, new_where);
end $mig$;
