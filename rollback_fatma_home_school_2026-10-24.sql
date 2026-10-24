-- Rollback (2026-10-24): فاطمة محمد القاسم محمود — المدرسة الأصلية الجمالية الابتدائية تعليم اساسي (كانت الجمالية تعليم اساسي الإعدادية)
begin;
update public.teacher_records set home_school_id='607ed619-9119-4da1-be1e-1c4d9501ffb7' where id='65bf3a29-1d09-46d6-ae64-f63070b98b95';
update public.teacher_school_assignments set is_home_school=true where id='4daf1a03-a7a9-49c7-b86e-e96223604997';
update public.teacher_school_assignments set is_home_school=false where id='98408b54-110e-4635-846f-9a0c25a8317d';
update public.delegations set from_school_id='607ed619-9119-4da1-be1e-1c4d9501ffb7', to_school_id='ba66c4f9-3ce8-458e-91e8-4bdae68c5f0f' where id='9a0bff10-91f2-4acd-8cef-3f0f0e223b48';
update public.delegations set from_school_id='607ed619-9119-4da1-be1e-1c4d9501ffb7' where id='7cad43d9-6b04-4da1-abcc-1130f52d8af3';
commit;
