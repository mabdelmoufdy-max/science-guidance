-- يُشغَّل من Supabase SQL Editor (أداة Claude لا تستطيع تنفيذ DROP).
-- يسمح بمنسقَين نشطين للمرحلة نفسها (المالك للعرض + شيماء بحسابها)، ويعيد لشيماء صلاحية منسق الإعدادي.
-- القيد (supervisor_id, stage) الفريد الموجود أصلًا يمنع تكرار الإسناد نفسه.
drop index if exists public.uq_one_active_stage_coordinator;
insert into public.stage_coordinator_assignments(supervisor_id, stage, active, assigned_by)
select s.id, 'إعدادي', true, '57e5112f-629b-479a-b7bd-8db465edcca3'
from public.supervisors s join public.profiles p on p.id = s.profile_id
where p.civil_id = '28106108800061'
on conflict (supervisor_id, stage) do update set active = true;
