-- استرجاع v153: إعادة حساب الأنصبة إلى ما قبل استثناء الإجازة المجددة (العمود on_renewed_leave يبقى بقيمة false لأن الـview لا تسمح بحذف عمود)
create or replace view public.teacher_workload_summary as
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
            base.leadership_periods +
                CASE
                    WHEN base.work_type = 'permanent'::work_type AND base.weekly_target IS NOT NULL AND (base.weekly_target - (base.teaching_periods + base.supervision_periods + base.leadership_periods)) = 1 THEN 1
                    ELSE 0
                END AS leadership_periods,
            base.weekly_target,
            base.workload_rule_type,
            base.teaching_periods + base.supervision_periods + base.leadership_periods +
                CASE
                    WHEN base.work_type = 'permanent'::work_type AND base.weekly_target IS NOT NULL AND (base.weekly_target - (base.teaching_periods + base.supervision_periods + base.leadership_periods)) = 1 THEN 1
                    ELSE 0
                END AS total_counted_periods
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
        END AS workload_status,
    false AS on_renewed_leave
   FROM totals
;

do $m$
declare d text; a text := E'\n      and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active where l.teacher_id=tr.id and l.renewal_status=''renewed'')  -- v153: الإجازة المجددة خارج الكشف';
begin
  d := pg_get_functiondef('private.school_teacher_roster'::regproc);
  if position(a in d)=0 then raise exception 'v153 line not found'; end if;
  execute replace(d, a, '');
end $m$;
