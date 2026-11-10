-- استرجاع v336a (2026-11-10): يعيد get_reports_dataset لفحص can_access_teacher لكل صف ويحذف الدالتين المساعدتين.
do $rb$
declare d text;
begin
  d := pg_get_functiondef('public.get_reports_dataset(uuid)'::regprocedure);
  d := replace(d,$a$where w.teacher_id in (select unnest(private.v336_visible_teacher_ids()))$a$,
                 $a$where (select private.current_app_role()) in ('admin','first_supervisor') or private.can_access_teacher(w.teacher_id)$a$);
  d := replace(d,$a$'teacher_records',(select private.v336_reports_teacher_records())$a$,
$a$'teacher_records',coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',t.id,
      'teacher_id',t.id,
      'profile_id',t.profile_id,
      'civil_id',t.civil_id,
      'full_name',t.full_name,
      'home_school_id',t.home_school_id,
      'job_title',t.job_title,
      'grade_acquired_date',t.grade_acquired_date,
      'work_start_date',t.work_start_date,
      'appointment_date',t.appointment_date,
      'work_type',t.work_type,
      'is_senior_teacher',t.is_senior_teacher,
      'active',t.active
    ) order by t.full_name)
    from public.teacher_records t
    where t.active
  ),'[]'::jsonb)$a$);
  if position('v336_' in d)>0 then raise exception 'rollback v336a: not fully reverted'; end if;
  execute d;
end $rb$;
drop function if exists private.v336_reports_teacher_records();
drop function if exists private.v336_visible_teacher_ids();
