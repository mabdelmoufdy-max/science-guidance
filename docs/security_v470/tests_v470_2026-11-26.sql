-- اختبارات v470 — للقراءة فقط (begin read only). شغّلها قبل التطبيق (تثبت المشكلة) وبعده (تثبت الإصلاح).
-- لا تطبع أسماء أو أرقامًا قومية: أعداد فقط.
begin read only;
-- مستخدم حقيقي بدور admin (للتأكد أن من يجب أن يرى ما زال يرى) — يُختار آليًا بلا طباعة بيانات
select set_config('t.admin', (select profile_id::text from public.user_roles where role='admin' and is_active limit 1), true);
select set_config('t.coord', (select profile_id::text from public.user_roles where role='stage_coordinator' and is_active limit 1), true);
select set_config('t.civ',  (select civil_id from public.teacher_records where civil_id is not null limit 1), true);
select set_config('t.out','',true);
set local role authenticated;
do $$ declare r text;
begin
  -- (أ) حساب بلا دور (= موظف مدرسة في الخيار أ)، مع ترويسة مزيفة admin
  perform set_config('request.jwt.claims','{"sub":"11111111-2222-3333-4444-555555555555","role":"authenticated"}',true);
  perform set_config('request.headers','{"x-app-role":"admin"}',true);
  r := (select count(*) from public.teacher_workload_summary)::text;              perform set_config('t.out',current_setting('t.out')||E'\nA1 roleless tws rows='||r,true);
  r := (select count(*) from public.teacher_official_staffing)::text;             perform set_config('t.out',current_setting('t.out')||E'\nA2 roleless staffing rows='||r,true);
  r := (select count(*) from public.school_supervisor_choice)::text;              perform set_config('t.out',current_setting('t.out')||E'\nA3 roleless ssc rows='||r,true);
  r := (public.lookup_identity_by_civil(current_setting('t.civ'))->>'exists');    perform set_config('t.out',current_setting('t.out')||E'\nA4 roleless lookup exists='||coalesce(r,'null'),true);
  -- (ب) مدير النظام الحقيقي
  perform set_config('request.jwt.claims',json_build_object('sub',current_setting('t.admin'),'role','authenticated')::text,true);
  perform set_config('request.headers','{"x-app-role":"admin"}',true);
  r := (select count(*) from public.teacher_workload_summary)::text;              perform set_config('t.out',current_setting('t.out')||E'\nB1 admin tws rows='||r,true);
  r := (select count(*) from public.school_supervisor_choice)::text;              perform set_config('t.out',current_setting('t.out')||E'\nB2 admin ssc rows='||r,true);
  r := (public.lookup_identity_by_civil(current_setting('t.civ'))->>'exists');    perform set_config('t.out',current_setting('t.out')||E'\nB3 admin lookup exists='||coalesce(r,'null'),true);
  -- (ج) منسق مرحلة حقيقي
  perform set_config('request.jwt.claims',json_build_object('sub',current_setting('t.coord'),'role','authenticated')::text,true);
  perform set_config('request.headers','{"x-app-role":"stage_coordinator"}',true);
  r := (select count(*) from public.teacher_workload_summary)::text;              perform set_config('t.out',current_setting('t.out')||E'\nC1 coord tws rows='||r,true);
  r := (select count(*) from public.school_supervisor_choice)::text;              perform set_config('t.out',current_setting('t.out')||E'\nC2 coord ssc rows='||r,true);
end $$;
select current_setting('t.out') as results;
rollback;
-- المتوقع قبل الإصلاح:  A1=434 A2=434 A3=110 A4=true | B1≈434 B2=110 B3=true | C1>0 C2=110
-- المتوقع بعد الإصلاح:  A1=0   A2=0   A3=0   A4=false | B و C بنفس أرقام «قبل» بالضبط
-- اختبار البند 4 (audit_insert) يحتاج إدراجًا فلا يُجرى هنا؛ يُتحقق منه بقراءة السياسة:
--   select with_check from pg_policies where tablename='audit_log' and policyname='audit_insert';  -- يجب أن يحوي IS NOT NULL
