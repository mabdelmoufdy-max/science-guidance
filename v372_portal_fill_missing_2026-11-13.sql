-- v372: بوابة المعلمين — المعلم يُكمل بياناته الناقصة فقط ويحفظها مباشرة (لا يكتب فوق قيمة مسجّلة)،
-- ورابطا واتساب لموجه المعلم ولمنسق المرحلة من بيانات البرنامج. بطلب المالك 2026-11-13.
alter table public.teacher_portal_settings add column if not exists fill_open boolean not null default true;

create or replace function public.teacher_portal_contacts(p_civil text, p_phone text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare c jsonb; t public.teacher_records; s record; a record; v_sups jsonb; v_coords jsonb;
begin
  c := private.tp_check(p_civil, p_phone);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['teacher_id','status','limited']);
  end if;
  select * into t from public.teacher_records where id = (c ->> 'teacher_id')::uuid;
  select id, name, stage, supervisor_id into s from public.schools where id = t.home_school_id;
  select * into a from private.tp_active();

  -- موجه المعلم: المسؤول المحدد يدويًا، وإلا موجه المدرسة، وإلا (الثانوي) موجه مادة يدرّسها، وإلا موجهو مواد المدرسة
  select coalesce(jsonb_agg(jsonb_build_object('name', x.full_name, 'phone', x.phone, 'subject', x.subject) order by x.subject nulls first, x.full_name), '[]'::jsonb)
    into v_sups
    from (
      select distinct sp.full_name, sp.phone, null::text as subject
        from public.teacher_responsible_supervisor r join public.supervisors sp on sp.id = r.supervisor_id and sp.active
       where r.teacher_id = t.id
    ) x;
  if jsonb_array_length(v_sups) = 0 and s.supervisor_id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('name', sp.full_name, 'phone', sp.phone, 'subject', null)), '[]'::jsonb)
      into v_sups from public.supervisors sp where sp.id = s.supervisor_id and sp.active;
  end if;
  if jsonb_array_length(v_sups) = 0 and s.id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('name', y.full_name, 'phone', y.phone, 'subject', y.subject_name) order by y.subject_name), '[]'::jsonb)
      into v_sups
      from (select distinct sp.full_name, sp.phone, ss.subject_name
              from public.supervisor_school_subjects ss join public.supervisors sp on sp.id = ss.supervisor_id and sp.active
             where ss.school_id = s.id and ss.active
               and ss.subject_name in (select cs.subject_name from public.teaching_assignments ta
                                         join public.curriculum_subjects cs on cs.id = ta.subject_id
                                        where ta.teacher_id = t.id and ta.term_id = a.term_id)) y;
    if jsonb_array_length(v_sups) = 0 then
      select coalesce(jsonb_agg(jsonb_build_object('name', y.full_name, 'phone', y.phone, 'subject', y.subject_name) order by y.subject_name), '[]'::jsonb)
        into v_sups
        from (select distinct sp.full_name, sp.phone, ss.subject_name
                from public.supervisor_school_subjects ss join public.supervisors sp on sp.id = ss.supervisor_id and sp.active
               where ss.school_id = s.id and ss.active) y;
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('name', sp.full_name, 'phone', sp.phone) order by sp.full_name), '[]'::jsonb)
    into v_coords
    from (select distinct sp.full_name, sp.phone
            from public.stage_coordinator_assignments ca join public.supervisors sp on sp.id = ca.supervisor_id and sp.active
           where ca.active and ca.stage = s.stage and coalesce(sp.phone, '') <> ''
             -- لا يظهر حساب مدير النظام (المالك) ضمن المنسقين للمعلمين
             and not exists (select 1 from public.user_roles ur where ur.profile_id = sp.profile_id and ur.is_active and ur.role::text = 'admin')) sp;

  return jsonb_build_object('ok', true, 'school', s.name, 'stage', s.stage, 'supervisors', v_sups, 'coordinators', v_coords);
end $f$;

create or replace function public.teacher_portal_fill_missing(p_civil text, p_phone text, p_fields jsonb)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare
  c jsonb; t public.teacher_records; v_open boolean; k text; v text; v_saved text[] := '{}';
  n_email text; n_res text; n_qual text; n_qyear int; n_spec text; n_appt date; n_ws date; n_grade date; n_code text;
  v_old jsonb := '{}'::jsonb; v_new jsonb := '{}'::jsonb; v_perm boolean;
begin
  c := private.tp_check(p_civil, p_phone);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['teacher_id','status','limited']);
  end if;
  if coalesce((c ->> 'limited')::boolean, false) then return jsonb_build_object('ok', false, 'reason', 'no_phone'); end if;
  select coalesce(fill_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not coalesce(v_open, true) then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if p_fields is null or jsonb_typeof(p_fields) <> 'object' then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;

  select * into t from public.teacher_records where id = (c ->> 'teacher_id')::uuid for update;
  v_perm := t.work_type = 'permanent';

  for k, v in select key, btrim(value) from jsonb_each_text(p_fields) loop
    if v is null or v = '' then continue; end if;
    begin
      if k = 'email' and coalesce(t.email, '') = '' then
        if length(v) > 120 or v !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'x'; end if;
        n_email := lower(v);
      elsif k = 'residence' and coalesce(t.residence, '') = '' then
        if length(v) < 2 or length(v) > 150 then raise exception 'x'; end if; n_res := v;
      elsif k = 'qualification' and coalesce(t.qualification, '') = '' then
        if length(v) < 2 or length(v) > 150 then raise exception 'x'; end if; n_qual := v;
      elsif k = 'qualification_year' and t.qualification_year is null then
        v := private.tp_digits(v);
        if v !~ '^[0-9]{4}$' or v::int < 1960 or v::int > extract(year from current_date)::int then raise exception 'x'; end if;
        n_qyear := v::int;
      elsif k = 'specialty' and coalesce(t.specialty, '') = '' then
        if v not in ('علوم', 'فيزياء', 'كيمياء', 'أحياء') then raise exception 'x'; end if; n_spec := v;
      elsif k = 'appointment_date' and t.appointment_date is null and v_perm then
        n_appt := v::date; if n_appt < date '1970-01-01' or n_appt > current_date then raise exception 'x'; end if;
      elsif k = 'work_start_date' and t.work_start_date is null then
        n_ws := v::date; if n_ws < date '1970-01-01' or n_ws > current_date then raise exception 'x'; end if;
      elsif k = 'grade_acquired_date' and t.grade_acquired_date is null and v_perm then
        n_grade := v::date; if n_grade < date '1970-01-01' or n_grade > current_date then raise exception 'x'; end if;
      elsif k = 'teacher_code' and coalesce(t.teacher_code, '') = '' then
        v := private.tp_digits(v);
        if v !~ '^[0-9]{6,8}$' then raise exception 'x'; end if;
        if exists (select 1 from public.teacher_records o where o.teacher_code = v and o.active and o.id <> t.id) then
          return jsonb_build_object('ok', false, 'reason', 'code_taken');
        end if;
        n_code := v;
      else
        continue; -- حقل مسجّل مسبقًا أو غير مسموح: لا يُكتب فوقه
      end if;
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', k);
    end;
    v_saved := v_saved || k;
  end loop;

  if array_length(v_saved, 1) is null then return jsonb_build_object('ok', false, 'reason', 'no_change'); end if;

  update public.teacher_records set
    email = coalesce(n_email, email),
    residence = coalesce(n_res, residence),
    qualification = coalesce(n_qual, qualification),
    qualification_year = coalesce(n_qyear, qualification_year),
    specialty = coalesce(n_spec, specialty),
    appointment_date = coalesce(n_appt, appointment_date),
    work_start_date = coalesce(n_ws, work_start_date),
    grade_acquired_date = coalesce(n_grade, grade_acquired_date),
    teacher_code = coalesce(n_code, teacher_code)
  where id = t.id;

  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
    values ('teacher', 'teacher_portal_fill_missing', 'teacher', t.id::text,
            jsonb_build_object('fields', to_jsonb(v_saved)),
            (select jsonb_object_agg(f, p_fields ->> f) from unnest(v_saved) f));
  return jsonb_build_object('ok', true, 'saved', to_jsonb(v_saved));
end $f$;

revoke all on function public.teacher_portal_contacts(text,text) from public;
revoke all on function public.teacher_portal_fill_missing(text,text,jsonb) from public;
grant execute on function public.teacher_portal_contacts(text,text) to anon, authenticated;
grant execute on function public.teacher_portal_fill_missing(text,text,jsonb) to anon, authenticated;
