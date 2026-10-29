-- v216: دالة قراءة فقط تُرجع حصر موجهي الثانوي بالمادة (لتقرير «نصاب الموجه من المدارس والمعلمين»).
-- SECURITY DEFINER لأن منسق الإعدادي لا يقرأ جداول الثانوي؛ تُقيَّد بأدوار admin / first_supervisor / stage_coordinator.
create or replace function public.secondary_supervisor_census(p_term_id uuid)
returns table(supervisor_id uuid, supervisor_name text, schools int, classes int, perm_teachers int, paid_teachers int)
language plpgsql stable security definer
set search_path to 'pg_catalog','public','pg_temp'
as $fn$
#variable_conflict use_column
begin
  if auth.uid() is null or private.current_app_role() not in ('admin','first_supervisor','stage_coordinator') then
    raise exception 'not allowed';
  end if;
  return query
  with sch as (
    select s.id, coalesce(s.aggregate_with_school_id, s.id) base from public.schools s where s.stage='ثانوي'
  ),
  base_schools as (select distinct base from sch),
  ss as (
    select distinct sch.base, x.supervisor_id, x.subject_name
    from public.supervisor_school_subjects x join sch on sch.id=x.school_id where x.active
  ),
  sup as (
    select base, supervisor_id, array_agg(distinct subject_name) subs from (
      select base, supervisor_id, subject_name from ss
      union
      select base, supervisor_id, 'علوم متكاملة' from ss where subject_name in ('الكيمياء','الأحياء')
    ) u group by base, supervisor_id
  ),
  cls as (
    select c.id, sch.base,
      array_agg(distinct cs.subject_name) filter (where r.weekly_periods>0) subs
    from public.school_classes c join sch on sch.id=c.school_id
    left join public.class_subject_requirements r on r.class_id=c.id
    left join public.curriculum_subjects cs on cs.id=r.subject_id
    where c.stage='ثانوي' and c.term_id=p_term_id group by c.id, sch.base
  ),
  tch as (
    select distinct c.base, a.teacher_id, cs.subject_name
    from public.teaching_assignments a join cls c on c.id=a.class_id
    join public.curriculum_subjects cs on cs.id=a.subject_id
    where a.term_id=p_term_id
  ),
  homet as (
    select distinct sch.base, t.id teacher_id, t.work_type
    from public.teacher_records t join sch on sch.id=t.home_school_id where t.active
  ),
  per_sup as (
    select sup.supervisor_id, sup.base,
      (select count(*) from cls c where c.base=sup.base and c.subs && sup.subs)::int n_cls
    from sup
  ),
  per_t as (
    select sup.supervisor_id, h.teacher_id, h.work_type
    from sup join tch on tch.base=sup.base and tch.subject_name = any(sup.subs)
    join homet h on h.base=tch.base and h.teacher_id=tch.teacher_id
    group by sup.supervisor_id, h.teacher_id, h.work_type
  )
  select sp.supervisor_id, v.full_name::text,
    count(*)::int,
    sum(sp.n_cls)::int,
    (select count(*) from per_t p where p.supervisor_id=sp.supervisor_id and p.work_type is distinct from 'paid')::int,
    (select count(*) from per_t p where p.supervisor_id=sp.supervisor_id and p.work_type='paid')::int
  from per_sup sp left join public.supervisors v on v.id=sp.supervisor_id
  group by sp.supervisor_id, v.full_name
  union all
  select null::uuid, 'غير مسندة', count(*)::int, 0, 0, 0
  from base_schools b where not exists (select 1 from sup where sup.base=b.base) having count(*)>0;
end $fn$;
revoke all on function public.secondary_supervisor_census(uuid) from public, anon;
grant execute on function public.secondary_supervisor_census(uuid) to authenticated;
