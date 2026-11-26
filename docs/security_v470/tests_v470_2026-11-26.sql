-- اختبارات v470 — لقاعدة اختبار فقط (نسخة مسترجعة من pg_dump أو فرع Supabase)، أبدًا على الإنتاج.
-- التشغيل:
--   psql "$TEST_DB" -v ON_ERROR_STOP=1 -c "set v470.i_am_test_db='yes'" ...   (انظر README: run_tests_v470.sh)
--   المرحلة: -v phase=before (قبل التطبيق: يثبت الثغرات) أو -v phase=after (بعده: يثبت الإصلاح)
-- كل البيانات اصطناعية (معرّفات وأرقام قومية وهمية) وتُلغى بـ rollback في النهاية.
-- الناتج: أعداد وPASS فقط. أي اختلاف عن المتوقع = RAISE EXCEPTION فيفشل الملف (ON_ERROR_STOP).
\set ON_ERROR_STOP 1
select set_config('v470.phase', :'phase', false);
begin;
do $$ begin
  if current_setting('v470.i_am_test_db', true) is distinct from 'yes' then
    raise exception 'اختبارات v470 لقاعدة اختبار فقط: اضبط v470.i_am_test_db=yes عمدًا'; end if;
  if current_setting('v470.phase') not in ('before','after') then raise exception 'phase يجب أن يكون before أو after'; end if;
end $$;

create function pg_temp.ok(p_name text, p_cond boolean, p_info text default '') returns void language plpgsql as $f$
begin
  if p_cond is not true then raise exception 'FAIL % (%)', p_name, p_info; end if;
  raise notice 'PASS % %', p_name, p_info;
end $f$;
create function pg_temp.as_user(p_uid text, p_role text) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('request.headers', json_build_object('x-app-role', coalesce(p_role, 'admin'))::text, true);
end $f$;
grant execute on function pg_temp.ok(text, boolean, text), pg_temp.as_user(text, text) to authenticated;

-- ===== بيانات اصطناعية (قد تحتاج أعمدة إلزامية إضافية في قاعدة الاختبار — عدّل هذا القسم فقط) =====
-- u1 بلا دور وبلا سجل | u2 بلا دور ومربوط بسجل معلم | u3 معلم | u4 مدير | u5 منسق | u6 موجه | u7 حساب المدرسة
insert into auth.users(id, email) select ('00000000-0000-4000-a000-00000000000'||i)::uuid, 'v470test'||i||'@test.invalid' from generate_series(1,7) i;
insert into public.profiles(id, full_name) select ('00000000-0000-4000-a000-00000000000'||i)::uuid, 'اختبار '||i from generate_series(2,7) i;
insert into public.user_roles(profile_id, role, is_active) values
 ('00000000-0000-4000-a000-000000000003','teacher',true), ('00000000-0000-4000-a000-000000000004','admin',true),
 ('00000000-0000-4000-a000-000000000005','stage_coordinator',true), ('00000000-0000-4000-a000-000000000006','supervisor',true),
 ('00000000-0000-4000-a000-000000000007','senior_teacher',true);
-- رقمان قوميان اصطناعيان بصيغة صحيحة (ليسا لأشخاص)
insert into public.teacher_records(id, profile_id, full_name, civil_id, work_type) values
 ('00000000-0000-4000-b000-000000000002','00000000-0000-4000-a000-000000000002','معلم اختبار بلا دور','29001012199991','permanent'),
 ('00000000-0000-4000-b000-000000000003','00000000-0000-4000-a000-000000000003','معلم اختبار','29001012199982','permanent');

-- المجاميع المرجعية بهوية المدير الاصطناعي (العرض يصفّي بالدور حتى للمالك بعد الإصلاح)
select pg_temp.as_user('00000000-0000-4000-a000-000000000004','admin');
select set_config('t.tws',   (select count(*) from public.teacher_workload_summary)::text,  true);
select set_config('t.tos',   (select count(*) from public.teacher_official_staffing)::text, true);
select set_config('t.ssc',   (select count(*) from public.school_supervisor_choice)::text,  true);
do $$ begin perform pg_temp.ok('fixture: totals > 0', current_setting('t.tws')::int > 0, 'tws='||current_setting('t.tws')); end $$;

set local role authenticated;
do $$
declare ph text := current_setting('v470.phase'); after boolean := ph = 'after';
  tws int := current_setting('t.tws')::int; tos int := current_setting('t.tos')::int; ssc int := current_setting('t.ssc')::int;
  n int; m int; s int; ex text; u record; ok boolean;
begin
  -- 1) حساب بلا دور (مع ترويسة مزيفة admin)
  perform pg_temp.as_user('00000000-0000-4000-a000-000000000001','admin');
  n := (select count(*) from public.teacher_workload_summary); m := (select count(*) from public.teacher_official_staffing);
  s := (select count(*) from public.school_supervisor_choice);
  ex := public.lookup_identity_by_civil('29001012199982')->>'exists';
  if after then
    perform pg_temp.ok('1a roleless tws=0', n = 0, 'n='||n);  perform pg_temp.ok('1b roleless staffing=0', m = 0, 'n='||m);
    perform pg_temp.ok('1c roleless ssc=0', s = 0, 'n='||s);  perform pg_temp.ok('1d roleless lookup exists=false', ex = 'false', 'exists='||coalesce(ex,'null'));
  else
    perform pg_temp.ok('1a BEFORE roleless sees all tws (leak)', n = tws, 'n='||n);
    perform pg_temp.ok('1d BEFORE roleless lookup exists=true (leak)', ex = 'true', 'exists='||coalesce(ex,'null'));
  end if;

  -- 2) بلا دور ومربوط بسجل معلم (ملاحظة 1)
  perform pg_temp.as_user('00000000-0000-4000-a000-000000000002','teacher');
  n := (select count(*) from public.teacher_workload_summary); m := (select count(*) from public.teacher_official_staffing);
  if after then
    perform pg_temp.ok('2a linked-roleless tws=0', n = 0, 'n='||n); perform pg_temp.ok('2b linked-roleless staffing=0', m = 0, 'n='||m);
  else
    perform pg_temp.ok('2a BEFORE linked-roleless sees rows (leak)', n > 0, 'n='||n);
  end if;

  -- 3) الأدوار الشرعية: الأعداد لا تتغير بين قبل وبعد
  for u in select * from (values
      ('00000000-0000-4000-a000-000000000003','teacher',           1,   false),
      ('00000000-0000-4000-a000-000000000004','admin',             -1,  true),
      ('00000000-0000-4000-a000-000000000005','stage_coordinator', -1,  true),
      ('00000000-0000-4000-a000-000000000006','supervisor',        -1,  true),
      ('00000000-0000-4000-a000-000000000007','senior_teacher',    -1,  true)) v(uid, role, exp_tws, lookup_ok) loop
    perform pg_temp.as_user(u.uid, u.role);
    n := (select count(*) from public.teacher_workload_summary); m := (select count(*) from public.teacher_official_staffing);
    perform pg_temp.ok('3 '||u.role||' tws', n = case when u.exp_tws = -1 then tws else u.exp_tws end, 'n='||n);
    perform pg_temp.ok('3 '||u.role||' staffing', m = case when u.exp_tws = -1 then tos else u.exp_tws end, 'n='||m);
    s := (select count(*) from public.school_supervisor_choice);
    perform pg_temp.ok('3 '||u.role||' ssc unchanged', s = ssc, 'n='||s);
    ex := public.lookup_identity_by_civil('29001012199982')->>'exists';
    if after then
      perform pg_temp.ok('3 '||u.role||' lookup', ex = case when u.lookup_ok then 'true' else 'false' end, 'exists='||coalesce(ex,'null'));
    end if;
  end loop;

  -- 4) إدراج سجل تدقيق (ملاحظة 5)
  if after then
    perform pg_temp.as_user('00000000-0000-4000-a000-000000000001','admin');
    begin insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id)
          values ('00000000-0000-4000-a000-000000000001','admin','v470_test','test','x'); ok := true;
    exception when insufficient_privilege or check_violation then ok := false; end;
    perform pg_temp.ok('4a roleless audit insert rejected', not ok);
  end if;
  perform pg_temp.as_user('00000000-0000-4000-a000-000000000004','admin');
  begin insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id)
        values ('00000000-0000-4000-a000-000000000004','admin','v470_test','test','x'); ok := true;
  exception when insufficient_privilege or check_violation then ok := false; end;
  perform pg_temp.ok('4b admin own audit insert accepted', ok);
  begin insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id)
        values ('00000000-0000-4000-a000-000000000005','admin','v470_test','test','x'); ok := true;
  exception when insufficient_privilege or check_violation then ok := false; end;
  perform pg_temp.ok('4c admin forged actor rejected', not ok);
  raise notice 'ALL PASS (phase=%)', ph;
end $$;
rollback;
