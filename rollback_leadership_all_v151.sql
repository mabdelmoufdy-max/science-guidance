-- استرجاع ما قبل v151 (الريادة لكل معلم ينقصه حصة): يعيد تعريفات v149 (الريادة التلقائية لـ«كبير معلمين» فقط) كما طُبّقت 2026-10-21
CREATE OR REPLACE VIEW public.teacher_workload_summary AS
 WITH teaching_totals AS (
         SELECT teaching_assignments.teacher_id,
            COALESCE(sum(teaching_assignments.weekly_periods), 0::bigint)::integer AS teaching_periods
           FROM teaching_assignments
          GROUP BY teaching_assignments.teacher_id
        ), leadership_totals AS (
         SELECT school_classes.leader_teacher_id AS teacher_id,
            count(*)::integer AS leadership_periods
           FROM school_classes
          WHERE school_classes.leader_teacher_id IS NOT NULL
          GROUP BY school_classes.leader_teacher_id
        ), base AS (
         SELECT tr.id AS teacher_id,
            tr.profile_id,
            tr.civil_id,
            tr.full_name,
            tr.work_type,
            tr.job_title,
            tr.home_school_id,
            s.name AS home_school_name,
            s.stage AS home_school_stage,
            tr.is_senior_teacher,
            COALESCE(tt.teaching_periods, 0) AS teaching_periods,
                CASE
                    WHEN tr.is_senior_teacher AND tr.work_type = 'permanent'::work_type THEN 2
                    ELSE 0
                END AS supervision_periods,
            COALESCE(lt.leadership_periods, 0) AS leadership_periods,
                CASE
                    WHEN tr.work_type = 'paid'::work_type THEN NULL::integer
                    WHEN s.stage = ANY (ARRAY['ابتدائي'::text, 'إعدادي'::text, 'ثانوي'::text]) THEN wr.weekly_norm
                    ELSE NULL::integer
                END AS weekly_target,
                CASE
                    WHEN tr.work_type = 'paid'::work_type THEN 'unrestricted'::text
                    WHEN s.stage = ANY (ARRAY['ابتدائي'::text, 'إعدادي'::text, 'ثانوي'::text]) THEN 'norm'::text
                    ELSE NULL::text
                END AS workload_rule_type
           FROM teacher_records tr
             LEFT JOIN schools s ON s.id = tr.home_school_id
             LEFT JOIN teaching_totals tt ON tt.teacher_id = tr.id
             LEFT JOIN leadership_totals lt ON lt.teacher_id = tr.id
             LEFT JOIN LATERAL ( SELECT wr_1.weekly_norm
                   FROM workload_rules wr_1
                  WHERE wr_1.stage = s.stage AND wr_1.active AND wr_1.job_title =
                        CASE
                            WHEN tr.job_title = ANY (ARRAY['معلم'::text, 'معلم مساعد'::text]) THEN 'معلم مساعد + معلم'::text
                            ELSE tr.job_title
                        END AND wr_1.effective_from <= CURRENT_DATE AND (wr_1.effective_to IS NULL OR wr_1.effective_to >= CURRENT_DATE)
                  ORDER BY wr_1.effective_from DESC
                 LIMIT 1) wr ON true
          WHERE tr.active
        ), totals AS (
         SELECT base.teacher_id,
            base.profile_id,
            base.civil_id,
            base.full_name,
            base.work_type,
            base.job_title,
            base.home_school_id,
            base.home_school_name,
            base.home_school_stage,
            base.is_senior_teacher,
            base.teaching_periods,
            base.supervision_periods,
            base.leadership_periods + CASE WHEN base.work_type = 'permanent'::work_type AND base.job_title = 'كبير معلمين'::text AND base.weekly_target IS NOT NULL AND (base.weekly_target - (base.teaching_periods + base.supervision_periods + base.leadership_periods)) = 1 THEN 1 ELSE 0 END AS leadership_periods,
            base.weekly_target,
            base.workload_rule_type,
            base.teaching_periods + base.supervision_periods + base.leadership_periods + CASE WHEN base.work_type = 'permanent'::work_type AND base.job_title = 'كبير معلمين'::text AND base.weekly_target IS NOT NULL AND (base.weekly_target - (base.teaching_periods + base.supervision_periods + base.leadership_periods)) = 1 THEN 1 ELSE 0 END AS total_counted_periods
           FROM base
        )
 SELECT teacher_id,
    profile_id,
    civil_id,
    full_name,
    work_type,
    job_title,
    home_school_id,
    home_school_name,
    home_school_stage,
    is_senior_teacher,
    teaching_periods,
    supervision_periods,
    leadership_periods,
    total_counted_periods,
    weekly_target,
    workload_rule_type,
        CASE
            WHEN weekly_target IS NULL THEN NULL::integer
            WHEN work_type = 'paid'::work_type THEN 0
            ELSE GREATEST(weekly_target - total_counted_periods, 0)
        END AS deficit_periods,
        CASE
            WHEN weekly_target IS NULL THEN NULL::integer
            ELSE GREATEST(total_counted_periods - weekly_target, 0)
        END AS surplus_periods,
        CASE
            WHEN weekly_target IS NULL THEN NULL::integer
            ELSE GREATEST(weekly_target - total_counted_periods, 0)
        END AS remaining_periods,
        CASE
            WHEN work_type = 'paid'::work_type THEN 'حسب الحصص المسندة'::text
            WHEN weekly_target IS NULL THEN 'غير محدد'::text
            WHEN total_counted_periods < weekly_target THEN 'عجز'::text
            WHEN total_counted_periods > weekly_target THEN 'زيادة'::text
            ELSE 'مكتمل'::text
        END AS workload_status
   FROM totals;

CREATE OR REPLACE FUNCTION private.school_teacher_roster(p_school_id uuid, p_term_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Unauthorized' using errcode='42501';
  end if;
  if not private.can_access_school(p_school_id) then
    raise exception 'المدرسة خارج نطاق صلاحيتك' using errcode='42501';
  end if;

  with roster_ids as (
    select tr.id
    from public.teacher_records tr
    where tr.active
      and (
        exists (
          select 1
          from public.teacher_school_assignments tsa
          where tsa.teacher_id=tr.id
            and tsa.school_id=p_school_id
            and tsa.term_id=p_term_id
            and tsa.active
            and (
              tsa.is_home_school
              or exists (
                select 1
                from public.delegations d
                where d.teacher_id=tr.id
                  and d.to_school_id=p_school_id
                  and d.active
                  and d.start_date<=current_date
                  and (d.end_date is null or d.end_date>=current_date)
              )
            )
        )
        or (
          tr.home_school_id=p_school_id
          and not exists (
            select 1
            from public.teacher_school_assignments tsa2
            where tsa2.teacher_id=tr.id and tsa2.term_id=p_term_id
          )
        )
      )
  ), scope_supervisor as (
    select tr.id as teacher_id
    from public.teacher_records tr
    join roster_ids ri on ri.id=tr.id
    where tr.active
      and tr.work_type='permanent'::public.work_type
      and not exists (
        select 1
        from public.delegations d
        where d.teacher_id=tr.id
          and d.to_school_id=p_school_id
          and d.delegation_type='partial'::public.delegation_type
          and d.active
          and d.start_date<=current_date
          and (d.end_date is null or d.end_date>=current_date)
      )
    order by public.teacher_job_grade_rank(tr.job_title) desc,
             tr.grade_acquired_date asc nulls last,
             tr.work_start_date asc nulls last,
             tr.appointment_date asc nulls last,
             tr.is_senior_teacher desc,
             tr.created_at asc,
             tr.id
    limit 1
  ), scope_teaching as (
    select a.teacher_id,coalesce(sum(a.weekly_periods),0)::integer as teaching_periods
    from public.teaching_assignments a
    join public.school_classes c on c.id=a.class_id
    where a.term_id=p_term_id and c.school_id=p_school_id
    group by a.teacher_id
  ), global_teaching as (
    select a.teacher_id,coalesce(sum(a.weekly_periods),0)::integer as teaching_periods
    from public.teaching_assignments a
    where a.term_id=p_term_id
    group by a.teacher_id
  ), scope_leadership as (
    select c.leader_teacher_id as teacher_id,count(*)::integer as leadership_periods
    from public.school_classes c
    where c.term_id=p_term_id
      and c.school_id=p_school_id
      and c.leader_teacher_id is not null
    group by c.leader_teacher_id
  ), global_leadership as (
    select c.leader_teacher_id as teacher_id,count(*)::integer as leadership_periods
    from public.school_classes c
    where c.term_id=p_term_id and c.leader_teacher_id is not null
    group by c.leader_teacher_id
  ), rows as (
    select
      w.*,
      tr.grade_acquired_date,
      tr.work_start_date,
      tr.appointment_date,
      sc.name as scope_school_name,
      sc.stage as scope_school_stage,
      coalesce(st.teaching_periods,0)::integer as scope_teaching_periods,
      coalesce(gt.teaching_periods,0)::integer as global_teaching_periods,
      coalesce(sl.leadership_periods,0)::integer as scope_leadership_periods,
      coalesce(gl.leadership_periods,0)::integer as global_leadership_periods,
      d.id as delegation_id,
      d.delegation_type,
      d.from_school_id as delegation_from_school_id,
      fs.name as delegation_from_school_name,
      d.to_school_id as delegation_to_school_id,
      ts.name as delegation_to_school_name,
      d.start_date as delegation_start_date,
      d.end_date as delegation_end_date,
      (ss.teacher_id=w.teacher_id) as scope_is_senior_teacher,
      case when ss.teacher_id=w.teacher_id and w.work_type='permanent'::public.work_type then 2 else 0 end::integer as scope_supervision_periods,
      case
        when w.work_type<>'permanent'::public.work_type then 0
        when d.to_school_id=p_school_id and d.delegation_type='partial'::public.delegation_type
          then case when coalesce(w.is_senior_teacher,false) then 2 else 0 end
        when ss.teacher_id=w.teacher_id then 2
        else 0
      end::integer as global_supervision_periods
    from public.teacher_workload_summary w
    join roster_ids ri on ri.id=w.teacher_id
    join public.teacher_records tr on tr.id=w.teacher_id
    join public.schools sc on sc.id=p_school_id
    left join scope_teaching st on st.teacher_id=w.teacher_id
    left join global_teaching gt on gt.teacher_id=w.teacher_id
    left join scope_leadership sl on sl.teacher_id=w.teacher_id
    left join global_leadership gl on gl.teacher_id=w.teacher_id
    left join scope_supervisor ss on true
    left join lateral (
      select d0.*
      from public.delegations d0
      where d0.teacher_id=w.teacher_id
        and d0.active
        and d0.start_date<=current_date
        and (d0.end_date is null or d0.end_date>=current_date)
        and (d0.from_school_id=p_school_id or d0.to_school_id=p_school_id)
      order by d0.start_date desc,d0.created_at desc
      limit 1
    ) d on true
    left join public.schools fs on fs.id=d.from_school_id
    left join public.schools ts on ts.id=d.to_school_id
  ), rows_auto as (
    -- الريادة التلقائية: حصة واحدة لـ«كبير معلمين» الدائم الناقص نصابه حصة واحدة بالضبط (لا تدخل في حصص العلوم)
    select rows.*,
      case when work_type='permanent'::public.work_type and job_title='كبير معلمين' and weekly_target is not null
        and weekly_target-(global_teaching_periods+global_leadership_periods+global_supervision_periods)=1 then 1 else 0 end::integer as global_auto_leadership_periods
    from rows
  ), rows_scope as (
    select rows_auto.*,
      case when delegation_to_school_id=p_school_id and delegation_type='partial'::public.delegation_type then 0 else global_auto_leadership_periods end::integer as scope_auto_leadership_periods
    from rows_auto
  ), calculated as (
    select rows_scope.*,
      (global_teaching_periods+global_leadership_periods+global_auto_leadership_periods+global_supervision_periods)::integer as global_total_counted_periods,
      (scope_teaching_periods+scope_leadership_periods+scope_auto_leadership_periods+scope_supervision_periods)::integer as scope_total_counted_periods
    from rows_scope
  )
  select coalesce(jsonb_agg(
    to_jsonb(calculated)
    || jsonb_build_object(
      'id',teacher_id,
      'is_senior_teacher',scope_is_senior_teacher,
      'supervision_periods',scope_supervision_periods,
      'teaching_periods',scope_teaching_periods,
      'leadership_periods',scope_leadership_periods+scope_auto_leadership_periods,
      'total_counted_periods',scope_total_counted_periods,
      'global_supervision_periods',global_supervision_periods,
      'global_teaching_periods',global_teaching_periods,
      'global_leadership_periods',global_leadership_periods+global_auto_leadership_periods,
      'global_total_counted_periods',global_total_counted_periods,
      'deficit_periods',case
        when weekly_target is null then null
        when work_type='paid'::public.work_type then 0
        else greatest(weekly_target-global_total_counted_periods,0)
      end,
      'surplus_periods',case when weekly_target is null then null else greatest(global_total_counted_periods-weekly_target,0) end,
      'remaining_periods',case when weekly_target is null then null else greatest(weekly_target-global_total_counted_periods,0) end,
      'workload_status',case
        when work_type='paid'::public.work_type then 'حسب الحصص المسندة'
        when weekly_target is null then 'غير محدد'
        when global_total_counted_periods<weekly_target then 'عجز'
        when global_total_counted_periods>weekly_target then 'زيادة'
        else 'مكتمل'
      end,
      'scope_school_id',p_school_id,
      'scope_school_name',scope_school_name,
      'scope_school_stage',scope_school_stage,
      'school_relation',case
        when delegation_to_school_id=p_school_id and home_school_id is distinct from p_school_id then 'delegated_in_'||delegation_type::text
        when delegation_from_school_id=p_school_id and delegation_type='partial'::public.delegation_type then 'delegated_out_partial'
        else 'home'
      end,
      'is_home_school',home_school_id=p_school_id
    )
    order by full_name
  ),'[]'::jsonb)
  into v_result
  from calculated;

  return v_result;
end;
$function$;
