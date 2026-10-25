-- استرجاع: توحيد سجل شيماء محمد فرج (2026-10-25)
-- يعيد: سجل 54161bac مربوطًا بحساب المالك، و2572cdbd بحساب شيماء نشطًا، وسجل المالك c69bd7db معطلًا.
begin;
update public.stage_coordinator_assignments set active=false where supervisor_id='c69bd7db-7904-4d25-b1fa-422ac5c87ec3';
update public.supervisor_stage_assignments set active=false where supervisor_id='c69bd7db-7904-4d25-b1fa-422ac5c87ec3';
update public.supervisors set profile_id=null, active=false where id='c69bd7db-7904-4d25-b1fa-422ac5c87ec3';
update public.supervisors set profile_id='57e5112f-629b-479a-b7bd-8db465edcca3' where id='54161bac-29ed-4276-a0e0-a45b23ca4b8e';
update public.supervisors set profile_id='99c8a791-547a-41be-86d7-ed0e3b7229b7', active=true where id='2572cdbd-2294-4616-acc2-38dfff0e085f';
update public.stage_coordinator_assignments set active=true where supervisor_id='2572cdbd-2294-4616-acc2-38dfff0e085f';
update public.supervisor_stage_assignments set active=true where supervisor_id='2572cdbd-2294-4616-acc2-38dfff0e085f';
commit;
