-- v427 بوابة المعلمين — مشرف المدرسة (ومسؤول البيانات والأساسي الوحيد): — 2026-11-20
-- بقول المستخدم «نفذ المقترح واترك ٤» (خطة docs/PLAN_portal_only_teachers.md البندان (ب) و(ج) معًا):
-- (ب) تعديل بيانات المدرسة الأساسية: بنين/بنات/مشترك، هاتف المدرسة، العنوان، اسم المدير وهاتفه.
--     «نوع المدرسة» مستبعد لأنه يغيّر حصص الفصول الجديدة (مهني) وفلاتر التقارير؛ والاسم والمرحلة والموجه للبرنامج فقط.
-- (ج) استكمال الحقول الفارغة فقط لمعلمي مدرسته الأصليين (نفس قواعد teacher_portal_fill_missing للمعلم).
-- إضافية فقط: عمود مفتاح + ثلاث دوال جديدة؛ لا تُعدَّل أي دالة قائمة.

alter table public.teacher_portal_settings add column if not exists school_edit_open boolean not null default true;

create or replace function public.teacher_portal_sup_school_details(p_civil text, p_phone text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private, pg_temp as $$
declare c jsonb; s public.schools; m public.school_manager_contact; v_open boolean;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['status','teacher_id','school_id','name','kind']); end if;
  select * into s from public.schools where id = (c ->> 'school_id')::uuid;
  if not found then return jsonb_build_object('ok', false, 'reason', 'no_school'); end if;
  select * into m from public.school_manager_contact where school_id = s.id;
  select coalesce(school_edit_open, true) into v_open from public.teacher_portal_settings where id = 1;
  return jsonb_build_object('ok', true, 'open', coalesce(v_open, true), 'school', jsonb_build_object(
    'id', s.id, 'name', s.name, 'stage', s.stage, 'school_type', s.school_type, 'gender_type', s.gender_type,
    'phone', s.phone, 'address', s.address, 'manager_name', m.manager_name, 'manager_phone', m.manager_phone));
end $$;

create or replace function public.teacher_portal_sup_school_update(p_civil text, p_phone text, p_fields jsonb)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private, pg_temp as $$
declare c jsonb; s public.schools; m public.school_manager_contact; v_open boolean; k text; v text;
  n_gender text; n_phone text; n_addr text; n_mname text; n_mphone text; v_saved text[] := '{}'; v_old jsonb := '{}'; v_new jsonb := '{}';
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['status','teacher_id','school_id','name','kind']); end if;
  select coalesce(school_edit_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not coalesce(v_open, true) then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if p_fields is null or jsonb_typeof(p_fields) <> 'object' then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  select * into s from public.schools where id = (c ->> 'school_id')::uuid for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'no_school'); end if;
  select * into m from public.school_manager_contact where school_id = s.id;
  for k, v in select key, btrim(value) from jsonb_each_text(p_fields) loop
    if v is null or v = '' then continue; end if;
    begin
      if k = 'gender_type' then
        if v not in ('بنين','بنات','مشترك') then raise exception 'x'; end if;
        if v is not distinct from s.gender_type then continue; end if; n_gender := v; v_old := v_old || jsonb_build_object(k, s.gender_type);
      elsif k = 'phone' then
        v := private.tp_digits(v); if v !~ '^[0-9]{6,15}$' then raise exception 'x'; end if;
        if v is not distinct from s.phone then continue; end if; n_phone := v; v_old := v_old || jsonb_build_object(k, s.phone);
      elsif k = 'address' then
        if length(v) < 2 or length(v) > 200 then raise exception 'x'; end if;
        if v is not distinct from s.address then continue; end if; n_addr := v; v_old := v_old || jsonb_build_object(k, s.address);
      elsif k = 'manager_name' then
        if length(v) < 2 or length(v) > 150 then raise exception 'x'; end if;
        if v is not distinct from m.manager_name then continue; end if; n_mname := v; v_old := v_old || jsonb_build_object(k, m.manager_name);
      elsif k = 'manager_phone' then
        v := private.tp_digits(v); if v !~ '^[0-9]{6,15}$' then raise exception 'x'; end if;
        if v is not distinct from m.manager_phone then continue; end if; n_mphone := v; v_old := v_old || jsonb_build_object(k, m.manager_phone);
      else continue;
      end if;
    exception when others then return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', k);
    end;
    v_saved := v_saved || k; v_new := v_new || jsonb_build_object(k, v);
  end loop;
  if array_length(v_saved, 1) is null then return jsonb_build_object('ok', false, 'reason', 'no_change'); end if;
  if n_gender is not null or n_phone is not null or n_addr is not null then
    update public.schools set gender_type = coalesce(n_gender, gender_type), phone = coalesce(n_phone, phone),
      address = coalesce(n_addr, address) where id = s.id;
  end if;
  if n_mname is not null or n_mphone is not null then
    insert into public.school_manager_contact(school_id, manager_name, manager_phone, set_by, updated_at)
    values (s.id, n_mname, n_mphone, null, now())
    on conflict (school_id) do update set manager_name = coalesce(excluded.manager_name, school_manager_contact.manager_name),
      manager_phone = coalesce(excluded.manager_phone, school_manager_contact.manager_phone), set_by = null, updated_at = now();
  end if;
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
  values ('senior_teacher'::app_role, 'teacher_portal_sup_school_update', 'school', s.id::text, v_old,
          v_new || jsonb_build_object('by_teacher_id', c ->> 'teacher_id', 'kind', c ->> 'kind'));
  return jsonb_build_object('ok', true, 'saved', to_jsonb(v_saved));
end $$;

create or replace function public.teacher_portal_sup_fill_missing(p_civil text, p_phone text, p_teacher_id uuid, p_fields jsonb)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private, pg_temp as $$
declare
  c jsonb; t public.teacher_records; v_open boolean; k text; v text; v_saved text[] := '{}';
  n_email text; n_res text; n_qual text; n_qyear int; n_spec text; n_appt date; n_ws date; n_grade date; n_code text; n_rel text; n_nat text; n_mar text; n_qtype text; n_qiss text; n_qgr text; n_qdate date;
  v_perm boolean;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['status','teacher_id','school_id','name','kind']); end if;
  select coalesce(fill_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not coalesce(v_open, true) then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if p_fields is null or jsonb_typeof(p_fields) <> 'object' then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  select * into t from public.teacher_records where id = p_teacher_id for update;
  if not found or not t.active or t.home_school_id is distinct from (c ->> 'school_id')::uuid then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
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
      elsif k = 'religion' and coalesce(t.religion, '') = '' then
        if v not in ('مسلم', 'مسيحي') then raise exception 'x'; end if; n_rel := v;
      elsif k = 'nationality' and coalesce(t.nationality, '') = '' then
        if length(v) < 2 or length(v) > 40 then raise exception 'x'; end if; n_nat := v;
      elsif k = 'marital_status' and coalesce(t.marital_status, '') = '' then
        if v not in ('أعزب', 'متزوج', 'مطلق', 'أرمل') then raise exception 'x'; end if; n_mar := v;
      elsif k = 'qualification_type' and coalesce(t.qualification_type, '') = '' then
        if v not in ('عليا', 'فوق المتوسط', 'متوسط') then raise exception 'x'; end if; n_qtype := v;
      elsif k = 'qualification_issuer' and coalesce(t.qualification_issuer, '') = '' then
        if length(v) < 2 or length(v) > 150 then raise exception 'x'; end if; n_qiss := v;
      elsif k = 'qualification_grade' and coalesce(t.qualification_grade, '') = '' then
        if v not in ('امتياز', 'جيد جدا', 'جيد', 'مقبول') then raise exception 'x'; end if; n_qgr := v;
      elsif k = 'qualification_date' and t.qualification_date is null then
        n_qdate := v::date; if n_qdate < date '1960-01-01' or n_qdate > current_date then raise exception 'x'; end if;
      else
        continue;
      end if;
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', k);
    end;
    v_saved := v_saved || k;
  end loop;
  if array_length(v_saved, 1) is null then return jsonb_build_object('ok', false, 'reason', 'no_change'); end if;
  update public.teacher_records set
    email = coalesce(n_email, email), residence = coalesce(n_res, residence), qualification = coalesce(n_qual, qualification),
    qualification_year = coalesce(n_qyear, qualification_year), specialty = coalesce(n_spec, specialty),
    appointment_date = coalesce(n_appt, appointment_date), work_start_date = coalesce(n_ws, work_start_date),
    grade_acquired_date = coalesce(n_grade, grade_acquired_date), teacher_code = coalesce(n_code, teacher_code),
    religion = coalesce(n_rel, religion), nationality = coalesce(n_nat, nationality), marital_status = coalesce(n_mar, marital_status),
    qualification_type = coalesce(n_qtype, qualification_type), qualification_issuer = coalesce(n_qiss, qualification_issuer),
    qualification_grade = coalesce(n_qgr, qualification_grade), qualification_date = coalesce(n_qdate, qualification_date)
  where id = t.id;
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
    values ('senior_teacher'::app_role, 'teacher_portal_sup_fill_missing', 'teacher', t.id::text,
            jsonb_build_object('fields', to_jsonb(v_saved)),
            (select jsonb_object_agg(f, p_fields ->> f) from unnest(v_saved) f)
              || jsonb_build_object('by_teacher_id', c ->> 'teacher_id', 'kind', c ->> 'kind'));
  return jsonb_build_object('ok', true, 'saved', to_jsonb(v_saved));
end $$;

revoke all on function public.teacher_portal_sup_school_details(text, text) from public;
revoke all on function public.teacher_portal_sup_school_update(text, text, jsonb) from public;
revoke all on function public.teacher_portal_sup_fill_missing(text, text, uuid, jsonb) from public;
grant execute on function public.teacher_portal_sup_school_details(text, text) to anon, authenticated;
grant execute on function public.teacher_portal_sup_school_update(text, text, jsonb) to anon, authenticated;
grant execute on function public.teacher_portal_sup_fill_missing(text, text, uuid, jsonb) to anon, authenticated;
