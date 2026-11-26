-- رجوع v470: يعيد التعريفات الأربعة حرفيًا من private.v470_backup، ويحذف سطر التدقيق الذي أضافه التطبيق فقط
-- (بمعرّفه المحفوظ)، ثم يحذف جدول النسخة. بعده يمكن إعادة التطبيق.
-- يحوي أمر حذف: يُشغَّل من SQL Editor (أداة Supabase تتوقف عنده).
begin;
do $$ begin
  if to_regclass('private.v470_backup') is null then raise exception 'rollback v470: غير مطبّق (لا نسخة احتياطية)'; end if;
  if (select count(*) from private.v470_backup where kind in ('view','function','policy')) <> 4 then
    raise exception 'rollback v470: النسخة الاحتياطية ناقصة — توقف'; end if;
end $$;
do $$ declare v text; begin
  select def into v from private.v470_backup where kind='view' and name='public.teacher_workload_summary';
  execute 'create or replace view public.teacher_workload_summary as ' || v;
  select def into v from private.v470_backup where kind='function' and name='public.lookup_identity_by_civil(text)';
  execute v;
  select def into v from private.v470_backup where name='public.school_supervisor_choice.ssc_read';
  execute format('alter policy ssc_read on public.school_supervisor_choice using (%s)', v);
  select extra into v from private.v470_backup where name='public.audit_log.audit_insert';
  execute format('alter policy audit_insert on public.audit_log with check (%s)', v);
end $$;
delete from public.audit_log
 where id = (select def::bigint from private.v470_backup where kind='audit' and name='apply_row')
   and action = 'v470_close_roleless_access';
drop table private.v470_backup;
commit;
