-- رجوع v470: يعيد التعريفات حرفيًا من private.v470_backup (المحفوظة لحظة التطبيق). لا يحذف جدول النسخة.
begin;
do $$ declare r record; begin
  if (select count(*) from private.v470_backup) <> 4 then raise exception 'rollback v470: النسخة الاحتياطية ناقصة'; end if;
  select def into r from private.v470_backup where kind='view' and name='public.teacher_workload_summary';
  execute 'create or replace view public.teacher_workload_summary as ' || r.def;
  select def into r from private.v470_backup where kind='function' and name='public.lookup_identity_by_civil(text)';
  execute r.def;
end $$;
do $$ declare q text; c text; begin
  select def, extra into q, c from private.v470_backup where name='public.school_supervisor_choice.ssc_read';
  execute format('alter policy ssc_read on public.school_supervisor_choice using (%s)', q);
  select extra into c from private.v470_backup where name='public.audit_log.audit_insert';
  execute format('alter policy audit_insert on public.audit_log with check (%s)', c);
end $$;
commit;
-- القيم المتوقعة بعد الرجوع (من فحص 2026-11-26):
--   ssc_read USING = true
--   audit_insert WITH CHECK = (actor_profile_id = ( SELECT auth.uid() AS uid))
--   شرط العرض: WHERE ((( SELECT private.current_app_role() AS current_app_role) IS DISTINCT FROM 'teacher'::app_role) OR (profile_id = ( SELECT auth.uid() AS uid)))
