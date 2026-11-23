create function public.school_deficit_before_paid()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $function$
begin
  if auth.uid() is null
    or coalesce(private.current_app_role()::text, '') not in ('admin', 'first_supervisor', 'stage_coordinator')
  then
    raise exception 'غير مصرح بعرض تقرير العجز قبل الأجر' using errcode = '42501';
  end if;

  return (
    with active_classes as (
      select c.id, c.school_id, c.term_id, c.stage, c.science_periods
      from public.school_classes c
      join public.terms t on t.id = c.term_id and t.is_active
    ), class_requirements as (
      select c.id, c.school_id, c.stage, c.science_periods,
             coalesce(sum(r.weekly_periods), 0) as periods
      from active_classes c
      left join public.class_subject_requirements r on r.class_id = c.id
      group by c.id, c.school_id, c.stage, c.science_periods
    ), school_requirements as (
      select school_id, count(*) as class_count, sum(periods) as required,
             bool_and(periods > 0 or coalesce(science_periods, 0) > 0
                      or coalesce(stage = 'إعدادي', false)) as has_class_periods
      from class_requirements
      group by school_id
    ), school_teaching as (
      select c.school_id, sum(a.weekly_periods) as permanent_teaching
      from active_classes c
      join public.teaching_assignments a on a.class_id = c.id and a.term_id = c.term_id
      join public.teacher_records t on t.id = a.teacher_id and t.work_type = 'permanent'
      group by c.school_id
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'school_id', s.id,
      'name', s.name,
      'stage', s.stage,
      'school_type', s.school_type,
      'required', coalesce(r.required, 0),
      'permanent_teaching', coalesce(a.permanent_teaching, 0),
      'deficit', greatest(coalesce(r.required, 0) - coalesce(a.permanent_teaching, 0), 0),
      'calculation_ready', greatest(coalesce(s.class_count, 0), coalesce(r.class_count, 0)) > 0
        and (s.stage = 'إعدادي' or (coalesce(r.class_count, 0) >= coalesce(s.class_count, 0)
                                   and coalesce(r.has_class_periods, false)))
    ) order by s.id), '[]'::jsonb)
    from public.schools s
    left join school_requirements r on r.school_id = s.id
    left join school_teaching a on a.school_id = s.id
  );
end;
$function$;

revoke all on function public.school_deficit_before_paid() from public, anon;
grant execute on function public.school_deficit_before_paid() to authenticated;
