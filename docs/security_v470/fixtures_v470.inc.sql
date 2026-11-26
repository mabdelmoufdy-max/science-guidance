-- بيانات اصطناعية مشتركة (تُضمَّن بـ \ir داخل معاملة تنتهي بـ rollback). لا بيانات حقيقية.
-- ما يلزم ليظهر سجل المعلم الاصطناعي في teacher_workload_summary / teacher_official_staffing
-- (مستنتج من migrations المستودع؛ يتأكد منه اختبار F1 أدناه):
--   auth.users(id) ← public.profiles(id) ← public.teacher_records(profile_id) مع active=true و work_type='permanent'
--   و home_school_id = مدرسة موجودة في public.schools (تُختار وقت التشغيل ولا تُطبع).
--   الدور: سطر في public.user_roles(profile_id, role, is_active=true)؛ والدور النشط يصل بترويسة x-app-role.
do $$ begin
  if to_regclass('v470_test_marker.marker') is null then
    raise exception 'ليست قاعدة اختبار (العلامة v470_test_marker.marker غير موجودة)' using errcode = 'V47T0'; end if;
end $$;

create function pg_temp.ok(p_name text, p_cond boolean, p_info text default '') returns void language plpgsql as $f$
begin
  if p_cond is not true then
    raise notice 'FAIL % %', p_name, p_info;
    raise exception using errcode = 'V47F0', message = 'test failed';
  end if;
  raise notice 'PASS % %', p_name, p_info;
end $f$;
create function pg_temp.as_user(p_uid text, p_role text) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('request.headers', json_build_object('x-app-role', coalesce(p_role, 'admin'))::text, true);
end $f$;
grant execute on function pg_temp.ok(text, boolean, text), pg_temp.as_user(text, text) to authenticated;

-- u1 بلا بروفايل ولا دور | u2 بروفايل + سجل معلم بلا دور | u3 معلم | u4 مدير | u5 منسق | u6 موجه
-- u7 حساب المدرسة (senior_teacher) | u8 موجه أول (first_supervisor) | u9 مدير مدرسة (school_manager)
insert into auth.users(id, email)
  select ('00000000-0000-4000-a000-00000000000'||i)::uuid, 'v470test'||i||'@test.invalid' from generate_series(1,9) i;
insert into public.profiles(id, full_name)
  select ('00000000-0000-4000-a000-00000000000'||i)::uuid, 'اختبار '||i from generate_series(2,9) i;
insert into public.user_roles(profile_id, role, is_active) values
 ('00000000-0000-4000-a000-000000000003','teacher',true), ('00000000-0000-4000-a000-000000000004','admin',true),
 ('00000000-0000-4000-a000-000000000005','stage_coordinator',true), ('00000000-0000-4000-a000-000000000006','supervisor',true),
 ('00000000-0000-4000-a000-000000000007','senior_teacher',true), ('00000000-0000-4000-a000-000000000008','first_supervisor',true),
 ('00000000-0000-4000-a000-000000000009','school_manager',true);
-- رقمان قوميان اصطناعيان بصيغة صحيحة (ليسا لأشخاص)
insert into public.teacher_records(id, profile_id, full_name, civil_id, work_type, home_school_id, active) values
 ('00000000-0000-4000-b000-000000000002','00000000-0000-4000-a000-000000000002','معلم اختبار بلا دور','29001012199991','permanent',(select id from public.schools order by id limit 1),true),
 ('00000000-0000-4000-b000-000000000003','00000000-0000-4000-a000-000000000003','معلم اختبار','29001012199982','permanent',(select id from public.schools order by id limit 1),true);

-- F1: السجلان الاصطناعيان يظهران فعلًا في العرضين (بهوية المدير)
select pg_temp.as_user('00000000-0000-4000-a000-000000000004','admin');
do $$ begin
  perform pg_temp.ok('F1 fixture rows visible in tws',
    (select count(*) from public.teacher_workload_summary where teacher_id in ('00000000-0000-4000-b000-000000000002','00000000-0000-4000-b000-000000000003')) = 2);
  perform pg_temp.ok('F1 fixture rows visible in staffing',
    (select count(*) from public.teacher_official_staffing where teacher_id in ('00000000-0000-4000-b000-000000000002','00000000-0000-4000-b000-000000000003')) = 2);
end $$;
