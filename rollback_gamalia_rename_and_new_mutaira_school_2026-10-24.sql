-- Rollback (2026-10-24): اسم «الجمالية تعليم اساسي اعدادي» ← «الجمالية تعليم اساسي»، وحذف المدرسة الجديدة «جزيرة مطيرة تعليم اساسي اعدادي الجديدة» (3 فصول)
-- يُشغَّل من SQL Editor (يحتوي حذفًا). لا يُحذف إن أُسندت فصولها بعد الإضافة.
begin;
set local session_replication_role = replica;
update public.schools set name='الجمالية تعليم اساسي' where id='607ed619-9119-4da1-be1e-1c4d9501ffb7';
commit;
begin;
delete from public.class_subject_requirements where class_id in (select id from public.school_classes where school_id='f753ce1d-b82f-43f9-b11f-78be242cace8');
delete from public.school_classes where school_id='f753ce1d-b82f-43f9-b11f-78be242cace8';
delete from public.schools where id='f753ce1d-b82f-43f9-b11f-78be242cace8';
commit;
