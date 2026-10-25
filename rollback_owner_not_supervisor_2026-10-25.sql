-- استرجاع: إزالة صفة «الموجه» عن حساب المالك (2026-10-25)
begin;
update public.supervisor_stage_assignments set active=true where supervisor_id='c69bd7db-7904-4d25-b1fa-422ac5c87ec3';
update public.user_roles set is_active=true where profile_id='57e5112f-629b-479a-b7bd-8db465edcca3' and role='supervisor';
commit;
