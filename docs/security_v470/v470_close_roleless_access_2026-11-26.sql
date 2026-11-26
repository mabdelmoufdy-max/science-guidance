-- v470: سد الوصول لأي حساب authenticated بلا دور (بنود 1–4 في function-audit.md)
-- لا تُشغَّل إلا بعد: موافقة صريحة + pg_dump محدّث + مراجعة ChatGPT.
-- القاعدة الموحدة للإصلاح: «لا شيء لمن current_app_role() = NULL» — كل مستخدمي البرنامج الحاليين لهم دور نشط
-- ويرسلون x-app-role، فلا يتغير لهم شيء. التعريفات القديمة تُحفظ أولًا في private.v470_backup (للرجوع الحرفي).
begin;

-- 0) نسخة احتياطية حرفية من كل ما سيتغير
create table if not exists private.v470_backup(
  kind text not null, name text not null, def text, extra text, saved_at timestamptz default now(),
  primary key(kind,name));
revoke all on private.v470_backup from public, anon, authenticated;
insert into private.v470_backup(kind,name,def) values
 ('view','public.teacher_workload_summary', pg_get_viewdef('public.teacher_workload_summary'::regclass)),
 ('function','public.lookup_identity_by_civil(text)', pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure));
insert into private.v470_backup(kind,name,def,extra)
 select 'policy', schemaname||'.'||tablename||'.'||policyname, qual, with_check
 from pg_policies where (schemaname,tablename,policyname) in (('public','school_supervisor_choice','ssc_read'),('public','audit_log','audit_insert'));
do $$ begin
  if (select count(*) from private.v470_backup) <> 4 then raise exception 'v470: النسخة الاحتياطية ناقصة — توقف'; end if;
end $$;

-- 1) البند 1 (عالي): العرض teacher_workload_summary
-- السبب: الشرط (role IS DISTINCT FROM 'teacher') = true عند role=NULL. نضيف (role IS NOT NULL) فقط؛
-- أقل تغيير ويحفظ الأعمدة والصلاحيات والعرض التابع teacher_official_staffing (security_invoker يقرأ منه).
do $$ declare d text; old text := '(( SELECT private.current_app_role() AS current_app_role) IS DISTINCT FROM ''teacher''::app_role)';
  new text := '((( SELECT private.current_app_role() AS current_app_role) IS NOT NULL) AND (( SELECT private.current_app_role() AS current_app_role) IS DISTINCT FROM ''teacher''::app_role))';
begin
  d := pg_get_viewdef('public.teacher_workload_summary'::regclass);
  if (length(d) - length(replace(d, old, ''))) / length(old) <> 1 then raise exception 'v470: شرط العرض ليس موجودًا مرة واحدة بالضبط — توقف'; end if;
  execute 'create or replace view public.teacher_workload_summary as ' || replace(d, old, new);
end $$;

-- 2) البند 2 (متوسط): school_supervisor_choice — القراءة لمن له دور فقط (البرنامج يقرؤه بدور نشط)
alter policy ssc_read on public.school_supervisor_choice
  using ((select private.current_app_role()) is not null);

-- 3) البند 3 (متوسط): lookup_identity_by_civil — رد «غير صالح» فورًا لمن لا دور له
-- السبب: الدالة يستعملها نموذج إضافة المعلم/الحساب لكل الأدوار؛ تقييدها بقائمة أدوار قد يوقف شاشة، فنمنع NULL فقط.
do $$ declare d text; n int;
begin
  d := pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure);
  n := (select count(*) from regexp_matches(d, E'\\nbegin\\n', 'gi'));
  if n < 1 then raise exception 'v470: لم يوجد begin في الدالة — توقف'; end if;
  d := regexp_replace(d, E'\\nbegin\\n',
    E'\nbegin\n  if (select private.current_app_role()) is null then return jsonb_build_object(''valid'', false, ''exists'', false); end if; -- v470\n', 'i');
  execute d;
end $$;

-- 4) البند 4 (منخفض): audit_insert — إدراج سجل التدقيق لمن له دور فقط
alter policy audit_insert on public.audit_log
  with check (actor_profile_id = (select auth.uid()) and (select private.current_app_role()) is not null);

-- تحقق داخلي قبل الإنهاء
do $$ begin
  if pg_get_viewdef('public.teacher_workload_summary'::regclass) not like '%IS NOT NULL%' then raise exception 'v470: العرض لم يتغير'; end if;
  if pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure) not like '%-- v470%' then raise exception 'v470: الدالة لم تتغير'; end if;
end $$;

insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
values ('admin','v470_close_roleless_access','security','v470', null,
        jsonb_build_object('items','teacher_workload_summary,ssc_read,lookup_identity_by_civil,audit_insert'));
commit;
