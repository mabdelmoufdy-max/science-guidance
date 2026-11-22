create table public.supervisor_personal (
  supervisor_id uuid primary key references public.supervisors(id) on delete cascade,
  religion text check (religion in ('مسلم', 'مسيحي')),
  nationality text check (char_length(nationality) between 2 and 40),
  marital_status text check (marital_status in ('أعزب', 'متزوج', 'مطلق', 'أرمل')),
  residence text check (char_length(residence) between 2 and 250),
  specialty text check (char_length(specialty) between 2 and 150),
  qualification_type text check (qualification_type in ('عليا', 'فوق المتوسط', 'متوسط')),
  qualification text check (char_length(qualification) between 2 and 150),
  qualification_issuer text check (char_length(qualification_issuer) between 2 and 150),
  qualification_grade text check (qualification_grade in ('امتياز', 'جيد جدا', 'جيد', 'مقبول')),
  qualification_date date check (qualification_date between date '1960-01-01' and current_date),
  updated_at timestamptz not null default now(),
  updated_by uuid not null
);

alter table public.supervisor_personal enable row level security;
revoke all on public.supervisor_personal from public, anon, authenticated;

create function public.get_supervisor_profile(p_supervisor_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $body$
declare
  actor uuid := auth.uid();
  app_role public.app_role := private.current_app_role();
  supervisor public.supervisors%rowtype;
  result jsonb;
begin
  select s.* into supervisor from public.supervisors s where s.id = p_supervisor_id;
  if actor is null or not found or not coalesce(
    app_role in ('admin', 'first_supervisor')
    or (app_role = 'supervisor' and supervisor.active and supervisor.profile_id = actor)
    or (app_role = 'stage_coordinator' and exists (
      select 1 from public.supervisor_stage_assignments a
      where a.supervisor_id = p_supervisor_id and a.active and private.can_access_stage(a.stage)
    )), false) then
    raise exception 'غير مصرح بعرض صحيفة الموجه' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'id', supervisor.id,
    'full_name', coalesce(nullif(supervisor.full_name, ''), p.full_name),
    'civil_id', coalesce(nullif(supervisor.civil_id, ''), p.civil_id),
    'phone', coalesce(nullif(supervisor.phone, ''), p.phone),
    'job_title', supervisor.job_title,
    'employment_grade', supervisor.employment_grade,
    'grade_date', supervisor.grade_date,
    'appointment_date', supervisor.appointment_date,
    'work_start_date', supervisor.work_start_date,
    'assignment_status', supervisor.assignment_status,
    'stages', coalesce((select jsonb_agg(a.stage order by a.stage)
      from public.supervisor_stage_assignments a where a.supervisor_id = supervisor.id and a.active), '[]'),
    'personal', coalesce(to_jsonb(d) - array['supervisor_id', 'updated_at', 'updated_by'], '{}'),
    'schools', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.stage, x.name, x.subject)
      from (
        select s.id, s.name, s.stage, null::text subject
        from public.schools s
        where s.supervisor_id = supervisor.id
          and (app_role <> 'stage_coordinator' or private.can_access_stage(s.stage))
        union
        select s.id, s.name, s.stage, a.subject_name
        from public.supervisor_school_subjects a join public.schools s on s.id = a.school_id
        where a.supervisor_id = supervisor.id and a.active
          and (app_role <> 'stage_coordinator' or private.can_access_stage(s.stage))
      ) x
    ), '[]')
  ) into result
  from (select 1) anchor
  left join public.profiles p on p.id = supervisor.profile_id
  left join public.supervisor_personal d on d.supervisor_id = supervisor.id;
  return result;
end
$body$;

create function public.save_supervisor_full_profile(p_supervisor_id uuid, p_fields jsonb)
returns void
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $body$
declare
  actor uuid := auth.uid();
  app_role public.app_role := private.current_app_role();
  supervisor public.supervisors%rowtype;
  fields jsonb;
  personal public.supervisor_personal%rowtype;
  previous_personal jsonb;
  previous_work jsonb;
  work_keys text[] := array['phone','job_title','employment_grade','grade_date',
    'appointment_date','work_start_date','full_name','assignment_status'];
begin
  if actor is null or app_role is null or app_role not in ('supervisor', 'admin') then
    raise exception 'غير مصرح بتعديل صحيفة الموجه' using errcode = '42501';
  end if;
  select s.* into supervisor from public.supervisors s
  where s.id = p_supervisor_id
    and (app_role = 'admin' or (s.profile_id = actor and s.active))
  for update;
  if not found then
    raise exception 'غير مصرح بتعديل صحيفة الموجه' using errcode = '42501';
  end if;
  if jsonb_typeof(p_fields) is distinct from 'object'
    or p_fields - (case when app_role = 'admin' then work_keys else work_keys[1:6] end)
                - array['religion','nationality','marital_status','residence','specialty',
                  'qualification_type','qualification','qualification_issuer','qualification_grade','qualification_date'] <> '{}' then
    raise exception 'توجد حقول غير مسموح بتعديلها' using errcode = '22023';
  end if;

  select coalesce(jsonb_object_agg(key, nullif(btrim(translate(value,
    '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')), '')), '{}')
    into fields from jsonb_each_text(p_fields);
  if fields ? 'phone' then
    fields := fields || jsonb_build_object('phone',
      nullif(regexp_replace(fields->>'phone', '[^0-9+]', '', 'g'), ''));
    if fields->>'phone' is not null and fields->>'phone' !~ '^[+]?[0-9]{6,15}$' then
      raise exception 'رقم الهاتف غير صحيح';
    end if;
  end if;
  if length(fields->>'job_title') > 150 or length(fields->>'employment_grade') > 150
     or (fields ? 'full_name' and fields->>'full_name' is null) then
    raise exception 'راجع الاسم والمسمى والدرجة';
  end if;
  select coalesce(jsonb_object_agg(key,value), '{}') into previous_work
  from jsonb_each(to_jsonb(supervisor)) where key = any(work_keys);
  supervisor := jsonb_populate_record(supervisor, fields);
  select d.* into personal from public.supervisor_personal d where d.supervisor_id = supervisor.id;
  previous_personal := coalesce(to_jsonb(personal) - array['supervisor_id','updated_at','updated_by'], '{}');
  personal := jsonb_populate_record(personal, fields);
  personal.supervisor_id := supervisor.id;
  personal.updated_at := now();
  personal.updated_by := actor;

  if fields ?| work_keys then
    update public.supervisors set phone = supervisor.phone, job_title = supervisor.job_title,
      employment_grade = supervisor.employment_grade, grade_date = supervisor.grade_date,
      appointment_date = supervisor.appointment_date, work_start_date = supervisor.work_start_date,
      full_name = supervisor.full_name, assignment_status = supervisor.assignment_status
    where id = supervisor.id;
    if app_role = 'supervisor' and fields ? 'phone' then
      update public.profiles set phone = supervisor.phone where id = actor and phone is distinct from supervisor.phone;
    end if;
  end if;

  if fields - work_keys <> '{}' then
    insert into public.supervisor_personal select (personal).*
    on conflict (supervisor_id) do update set
      religion = excluded.religion, nationality = excluded.nationality,
      marital_status = excluded.marital_status, residence = excluded.residence, specialty = excluded.specialty,
      qualification_type = excluded.qualification_type, qualification = excluded.qualification,
      qualification_issuer = excluded.qualification_issuer, qualification_grade = excluded.qualification_grade,
      qualification_date = excluded.qualification_date, updated_at = excluded.updated_at, updated_by = excluded.updated_by;
  end if;

  -- يسجل الأثر مع أسماء الحقول المتغيرة دون نسخ البيانات الشخصية إلى سجل التدقيق.
  insert into public.audit_log(actor_profile_id, action, entity_type, entity_id, new_data)
  select actor, 'save_supervisor_full_profile', 'supervisors', supervisor.id::text,
    jsonb_build_object('changed_fields', coalesce(jsonb_agg(key order by key), '[]'))
  from jsonb_each(fields)
  where coalesce((previous_work || previous_personal)->key, 'null') is distinct from
    coalesce((to_jsonb(supervisor) || to_jsonb(personal))->key, 'null');
end
$body$;

revoke all on function public.get_supervisor_profile(uuid) from public, anon;
revoke all on function public.save_supervisor_full_profile(uuid, jsonb) from public, anon;
grant execute on function public.get_supervisor_profile(uuid) to authenticated;
grant execute on function public.save_supervisor_full_profile(uuid, jsonb) to authenticated;
