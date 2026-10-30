-- استرجاع v228: يزيل شرط النطاق من قائمة المعلمين في get_reports_dataset (يعيد إرسال كل المعلمين لكل دور — الثغرة السابقة).
do $mig$
declare d text;
  old_where text := E'      from public.teacher_workload_summary w\n    ),''[]''::jsonb)';
  new_where text := E'      from public.teacher_workload_summary w\n      where (select private.current_app_role()) in (''admin'',''first_supervisor'') or private.can_access_teacher(w.teacher_id)  -- v228: نطاق المستخدم فقط\n    ),''[]''::jsonb)';
begin
  d := pg_get_functiondef('public.get_reports_dataset(uuid)'::regprocedure);
  if (length(d) - length(replace(d, new_where, ''))) / length(new_where) <> 1 then raise exception 'rollback v228: anchor count <> 1'; end if;
  execute replace(d, new_where, old_where);
end $mig$;
