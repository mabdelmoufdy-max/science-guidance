-- اختبارات v470 — قاعدة اختبار فقط (يرفض التشغيل بدون العلامة v470_test_marker من setup_test_db_v470.sql).
-- يُشغَّل عبر docs/security_v470/tests_cycle_v470_2026-11-26.sh (من جذر المستودع)، أو مباشرة:
--   psql "$TEST_DB" -X -v ON_ERROR_STOP=1 -v phase=before|after -f docs/security_v470/tests_v470_2026-11-26.sql
-- المخرجات: PASS/FAIL باسم الاختبار وأعداد فقط؛ الأخطاء بكود SQLSTATE فقط (VERBOSITY sqlstate). بيانات اصطناعية تُلغى بـ rollback.
\set ON_ERROR_STOP 1
\if :{?keep_verbosity}
\else
\set VERBOSITY sqlstate
\endif
select set_config('v470.phase', :'phase', false) \g /dev/null
begin;
\ir fixtures_v470.inc.sql
do $$ begin
  if current_setting('v470.phase') not in ('before','after') then raise exception using errcode = 'V47T1', message = 'bad phase'; end if;
end $$;
select set_config('t.tws', (select count(*) from public.teacher_workload_summary)::text,  true) \g /dev/null
select set_config('t.tos', (select count(*) from public.teacher_official_staffing)::text, true) \g /dev/null
select set_config('t.ssc', (select count(*) from public.school_supervisor_choice)::text,  true) \g /dev/null

set local role authenticated;
do $$
declare after boolean := current_setting('v470.phase') = 'after';
  tws int := current_setting('t.tws')::int; tos int := current_setting('t.tos')::int; ssc int := current_setting('t.ssc')::int;
  n int; m int; s int; ex text; u record; ok boolean; st text;
  ins text := 'insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id) values ($1, $2, ''v470_test'', ''test'', ''x'')';
begin
  perform pg_temp.ok('0 baseline counts > 0', tws > 0 and tos > 0, 'tws='||tws);

  -- 1) بلا بروفايل ولا دور (ترويسة مزيفة admin)
  perform pg_temp.as_user('00000000-0000-4000-a000-000000000001','admin');
  perform pg_temp.ok('1 role(u1) is null', private.current_app_role() is null);
  n := (select count(*) from public.teacher_workload_summary); m := (select count(*) from public.teacher_official_staffing);
  s := (select count(*) from public.school_supervisor_choice); ex := public.lookup_identity_by_civil('29001012199982')->>'exists';
  if after then
    perform pg_temp.ok('1a roleless tws=0', n = 0, 'n='||n);  perform pg_temp.ok('1b roleless staffing=0', m = 0, 'n='||m);
    perform pg_temp.ok('1c roleless ssc=0', s = 0, 'n='||s);  perform pg_temp.ok('1d roleless lookup exists=false', ex = 'false');
  else
    perform pg_temp.ok('1a BEFORE roleless sees all tws (leak)', n = tws, 'n='||n);
    perform pg_temp.ok('1d BEFORE roleless lookup exists=true (leak)', ex = 'true');
  end if;

  -- 2) بروفايل صالح + سجل معلم، بلا دور
  perform pg_temp.as_user('00000000-0000-4000-a000-000000000002','teacher');
  perform pg_temp.ok('2 role(u2) is null', private.current_app_role() is null);
  n := (select count(*) from public.teacher_workload_summary); m := (select count(*) from public.teacher_official_staffing);
  if after then
    perform pg_temp.ok('2a linked-roleless tws=0', n = 0, 'n='||n); perform pg_temp.ok('2b linked-roleless staffing=0', m = 0, 'n='||m);
  else
    perform pg_temp.ok('2a BEFORE linked-roleless sees rows (leak)', n > 0, 'n='||n);
  end if;

  -- 3) الأدوار: العدّ لا يتغير؛ lookup للأدوار الأربعة فقط (senior_teacher مقصود) والدوران الخامس والسادس مرفوضان
  for u in select * from (values
      ('00000000-0000-4000-a000-000000000003','teacher',            1, false),
      ('00000000-0000-4000-a000-000000000004','admin',             -1, true),
      ('00000000-0000-4000-a000-000000000005','stage_coordinator', -1, true),
      ('00000000-0000-4000-a000-000000000006','supervisor',        -1, true),
      ('00000000-0000-4000-a000-000000000007','senior_teacher',    -1, true),
      ('00000000-0000-4000-a000-000000000008','first_supervisor',  -1, false),
      ('00000000-0000-4000-a000-000000000009','school_manager',    -1, false)) v(uid, role, exp_tws, lookup_ok) loop
    perform pg_temp.as_user(u.uid, u.role);
    perform pg_temp.ok('3 role('||u.role||') active', private.current_app_role()::text = u.role);
    n := (select count(*) from public.teacher_workload_summary); m := (select count(*) from public.teacher_official_staffing);
    perform pg_temp.ok('3 '||u.role||' tws', n = case when u.exp_tws = -1 then tws else u.exp_tws end, 'n='||n);
    perform pg_temp.ok('3 '||u.role||' staffing', m = case when u.exp_tws = -1 then tos else u.exp_tws end, 'n='||m);
    s := (select count(*) from public.school_supervisor_choice);
    perform pg_temp.ok('3 '||u.role||' ssc unchanged', s = ssc, 'n='||s);
    ex := public.lookup_identity_by_civil('29001012199982')->>'exists';
    if after then
      perform pg_temp.ok('3 '||u.role||' lookup '||case when u.lookup_ok then 'allowed' else 'rejected' end,
                         ex = case when u.lookup_ok then 'true' else 'false' end);
    else
      perform pg_temp.ok('3 BEFORE '||u.role||' lookup open', ex = 'true');
    end if;
  end loop;

  -- 4) إدراج التدقيق
  perform pg_temp.as_user('00000000-0000-4000-a000-000000000002','admin');   -- بروفايل صالح بلا دور
  begin execute ins using '00000000-0000-4000-a000-000000000002'::uuid, 'admin'; ok := true;
  exception when others then ok := false; st := sqlstate; end;
  if after then perform pg_temp.ok('4a profile-without-role audit insert rejected', not ok and st = '42501', 'sqlstate='||coalesce(st,'none'));
  else perform pg_temp.ok('4a BEFORE profile-without-role audit insert accepted (gap)', ok); end if;
  perform pg_temp.as_user('00000000-0000-4000-a000-000000000004','admin'); st := null;
  begin execute ins using '00000000-0000-4000-a000-000000000004'::uuid, 'admin'; ok := true;
  exception when others then ok := false; st := sqlstate; end;
  perform pg_temp.ok('4b admin own identity accepted', ok, 'sqlstate='||coalesce(st,'none'));
  st := null;
  begin execute ins using '00000000-0000-4000-a000-000000000005'::uuid, 'admin'; ok := true;
  exception when others then ok := false; st := sqlstate; end;
  perform pg_temp.ok('4c admin forged identity rejected', not ok and st = '42501', 'sqlstate='||coalesce(st,'none'));
  raise notice 'ALL PASS (phase=%)', current_setting('v470.phase');
end $$;
rollback;
