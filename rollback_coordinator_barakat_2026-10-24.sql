-- استرجاع حساب منسق المرحلة الابتدائية: بركات محمد محمود عبدالله (2026-10-24)
-- يُشغَّل من SQL Editor. يحذف الحساب ويفك ربط سجل الموجه ويحذف إسناد المنسق؛ سجل الموجه ومدارسه الـ22 تبقى.
begin;
delete from public.stage_coordinator_assignments a using public.supervisors s where s.id=a.supervisor_id and s.civil_id='27109062701238';
update public.supervisors set profile_id=null where civil_id='27109062701238';
delete from public.user_roles where profile_id in (select id from public.profiles where civil_id='27109062701238');
delete from public.profiles where civil_id='27109062701238';
delete from auth.users where email='27109062701238@science-guidance.local';
commit;
