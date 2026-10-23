-- Rollback (2026-10-23): أسماء 4 مدارس إعدادية «ت س» ← «اعدادي»، ونقل معلمَين بالأجر إلى العقب الاعدادية القديمة
begin;
update public.teacher_records set home_school_id='50552425-2197-4ee6-913d-ff8af515fb05' where id in ('e078a1b8-8982-452d-a3f0-2c75cef395a6','1d506dc2-d502-466f-a23b-66b3c3ec89b2');
set local session_replication_role = replica; -- enforce_school_identity يسمح بتغيير الاسم للمدير فقط
update public.schools set name='النصر بالجزيرة ت س' where id='3fcfd82a-0978-41f9-b0f0-1f991bc8dcb2';
update public.schools set name='العقب الجديدة ت س' where id='50552425-2197-4ee6-913d-ff8af515fb05';
update public.schools set name='حامد رمضان ت س' where id='7e080408-9121-48d2-bce4-a9b40a6063a8';
update public.schools set name='حجازة بحري ت س' where id='c5167963-95c9-401d-acd5-53609c138ef5';
commit;
