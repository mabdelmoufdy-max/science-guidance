alter table public.supervisors add column if not exists grade_date date;
grant update (grade_date) on public.supervisors to authenticated;

create or replace function public.update_my_supervisor_profile(
  p_phone text, p_job_title text, p_employment_grade text,
  p_grade_date date, p_appointment_date date, p_work_start_date date)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_id uuid;
  v_phone text := nullif(regexp_replace(translate(coalesce(p_phone,''),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g'),'');
  v_old public.supervisors%rowtype;
  v_new public.supervisors%rowtype;
begin
  if auth.uid() is null then raise exception 'غير مصرح' using errcode='42501'; end if;
  if private.current_app_role() <> 'supervisor' then
    raise exception 'هذه الشاشة للموجه فقط' using errcode='42501';
  end if;
  v_id := private.current_supervisor_id();
  if v_id is null then raise exception 'لا يوجد سجل موجه مرتبط بحسابك' using errcode='42501'; end if;
  if v_phone is not null and v_phone !~ '^\+?[0-9]{6,15}$' then raise exception 'رقم الهاتف غير صحيح'; end if;
  if char_length(coalesce(p_job_title,''))>150 or char_length(coalesce(p_employment_grade,''))>150 then
    raise exception 'النص أطول من المسموح';
  end if;

  select * into v_old from public.supervisors where id=v_id;
  update public.supervisors set
    phone=v_phone,
    job_title=nullif(btrim(coalesce(p_job_title,'')),''),
    employment_grade=nullif(btrim(coalesce(p_employment_grade,'')),''),
    grade_date=p_grade_date,
    appointment_date=p_appointment_date,
    work_start_date=p_work_start_date
  where id=v_id returning * into v_new;

  update public.profiles set phone=v_phone where id=auth.uid() and phone is distinct from v_phone;

  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,old_data,new_data)
  values(auth.uid(),'update_my_supervisor_profile','supervisors',v_id::text,
    jsonb_build_object('phone',v_old.phone,'job_title',v_old.job_title,'employment_grade',v_old.employment_grade,'grade_date',v_old.grade_date,'appointment_date',v_old.appointment_date,'work_start_date',v_old.work_start_date),
    jsonb_build_object('phone',v_new.phone,'job_title',v_new.job_title,'employment_grade',v_new.employment_grade,'grade_date',v_new.grade_date,'appointment_date',v_new.appointment_date,'work_start_date',v_new.work_start_date));

  return jsonb_build_object('id',v_new.id,'phone',v_new.phone,'job_title',v_new.job_title,'employment_grade',v_new.employment_grade,
    'grade_date',v_new.grade_date,'appointment_date',v_new.appointment_date,'work_start_date',v_new.work_start_date);
end
$function$;

revoke all on function public.update_my_supervisor_profile(text,text,text,date,date,date) from public, anon;
grant execute on function public.update_my_supervisor_profile(text,text,text,date,date,date) to authenticated;
