-- Rollback: coordinator accounts created 2026-10-23
-- (محمد معله الطاهر محمد — ثانوي، ايمن وهيب رزق عبدالنور — ابتدائي، شيماء محمد فرج محمد — إعدادي)
-- and the owner's independent supervisor record. Restores Shaimaa's supervisor record link to the owner account.
begin;
-- remove coordinator assignments added for Mohamed and Ayman (Shaimaa's assignment pre-existed and stays)
delete from public.stage_coordinator_assignments a using public.supervisors s
 where s.id=a.supervisor_id and s.civil_id in ('27710142700637','28007072701613');
-- unlink supervisor records from the new accounts
update public.supervisors set profile_id=null where civil_id in ('27710142700637','28007072701613','28106108800061');
-- owner's independent supervisor record
delete from public.supervisor_stage_assignments a using public.supervisors s
 where s.id=a.supervisor_id and s.civil_id='27706152701553';
delete from public.supervisors where civil_id='27706152701553';
-- relink Shaimaa's record to the owner account (as before 2026-10-23)
update public.supervisors set profile_id='57e5112f-629b-479a-b7bd-8db465edcca3' where id='54161bac-29ed-4276-a0e0-a45b23ca4b8e';
-- delete the three accounts
delete from public.user_roles where profile_id in (select id from public.profiles where civil_id in ('27710142700637','28007072701613','28106108800061'));
delete from public.profiles where civil_id in ('27710142700637','28007072701613','28106108800061');
delete from auth.users where email in ('27710142700637@science-guidance.local','28007072701613@science-guidance.local','28106108800061@science-guidance.local');
commit;
