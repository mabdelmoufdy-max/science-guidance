-- Rollback: رشا عبد الرحيم امين — المدرسة الأصلية النيل الابتدائية بقوص + انتداب جزئي للبهاء زهير ع (2026-10-23)
-- يعيدها إلى البهاء زهير ع (أصلية) بانتداب جزئي بلا مدرسة مصدر كما كانت. ويحذف قيد رفض الإشراف لرانيا (الشعراني) المضاف مع v176.
begin;
delete from public.supervision_declined where teacher_id='f28c426a-814f-4512-807b-d57aa1766d6f' and school_id='f116aba8-b8fe-4646-b620-fa7c13262060';
delete from public.teacher_school_assignments where teacher_id='f28c426a-814f-4512-807b-d57aa1766d6f' and school_id='385a3919-63e4-49fc-bb30-effb8a74388d' and not is_home_school;
update public.teacher_school_assignments set school_id='385a3919-63e4-49fc-bb30-effb8a74388d' where id='a2b4e1ec-837d-4248-a027-d8e6b4e3a193';
update public.teacher_records set home_school_id='385a3919-63e4-49fc-bb30-effb8a74388d' where id='f28c426a-814f-4512-807b-d57aa1766d6f';
update public.delegations set from_school_id=null where id='0771d4ba-13e1-4df1-b7b3-3e4ceb7c6d0c';
commit;
