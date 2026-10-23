-- Rollback: موسى محمد عبدالقادر — المدرسة الأصلية المعري المهني وإلغاء الانتداب الجزئي (2026-10-23)
begin;
update public.delegations set active=true where id='b6e6092c-452b-4436-9fc6-a24f96f4a0b8';
update public.teacher_school_assignments set is_home_school=false where id='72911359-c99b-4bad-a8f9-6b128f1636d8';
update public.teacher_records set home_school_id=null where id='9e805e2e-d5a6-43bb-83df-fa1747326b61';
commit;
