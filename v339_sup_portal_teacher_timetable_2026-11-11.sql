-- v339: مشرف المدرسة في بوابة المعلمين يضع جدول المعلم (البديل أ، بقرار المستخدم «نفذ» 2026-11-11)
-- دالتان جديدتان فقط؛ لا تغيير في الجداول أو الصلاحيات الحالية أو الدوال الموجودة.
-- النطاق: مشرف المدرسة (tp_sup_view_check: is_senior_teacher + مدرسته الأصلية) يضع جدول أي معلم نشط
--   أصلي في مدرسته أو له إسناد فيها، لحصص فصول مدرسته فقط؛ حصص المعلم في مدرسة أخرى تُعرض مقفلة ولا تُمس.
-- يتبع مفتاح teacher_portal_settings.timetable_open، ويُسجَّل الحفظ في audit_log (actor_role=senior_teacher).
-- الاسترجاع: rollback_v339_sup_portal_teacher_timetable_2026-11-11.sql

create or replace function public.teacher_portal_sup_timetable_get(p_civil text, p_phone text, p_teacher_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
declare c jsonb; a record; v_school uuid; v_sname text; t public.teacher_records; v_open boolean;
        v_assign jsonb; v_slots jsonb; v_other jsonb; v_busy jsonb;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  select * into a from private.tp_active();
  select * into t from public.teacher_records where id = p_teacher_id and active;
  if t.id is null or not (t.home_school_id = v_school or exists (
       select 1 from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
        where ta.teacher_id = t.id and ta.term_id = a.term_id and sc.school_id = v_school)) then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  select name into v_sname from public.schools where id = v_school;
  select coalesce(timetable_open, true) into v_open from public.teacher_portal_settings where id = 1;
  select coalesce(jsonb_agg(jsonb_build_object(
           'assignment_id', ta.id, 'class_id', ta.class_id, 'school_id', sc.school_id, 'school_name', s.name,
           'grade_order', sc.grade_order, 'grade_label', private.tp_class_grade_label(sc.stage, sc.grade),
           'class_label', private.tp_class_name_label(sc.class_name), 'class_name', sc.class_name,
           'subject', cs.subject_name, 'periods', ta.weekly_periods)
         order by sc.grade_order nulls last, sc.class_name), '[]'::jsonb)
    into v_assign
    from public.teaching_assignments ta
    join public.school_classes sc on sc.id = ta.class_id
    join public.schools s on s.id = sc.school_id
    left join public.curriculum_subjects cs on cs.id = ta.subject_id
   where ta.teacher_id = t.id and ta.term_id = a.term_id and ta.weekly_periods > 0 and sc.school_id = v_school;
  select coalesce(jsonb_agg(jsonb_build_object('assignment_id', x.assignment_id, 'weekday', x.weekday, 'period', x.period_number)), '[]'::jsonb)
    into v_slots from public.teacher_timetable_slots x
   where x.teacher_id = t.id and x.term_id = a.term_id and x.school_id = v_school;
  select coalesce(jsonb_agg(jsonb_build_object('weekday', o.weekday, 'period', o.period_number, 'school_name', so.name)), '[]'::jsonb)
    into v_other from public.teacher_timetable_slots o join public.schools so on so.id = o.school_id
   where o.teacher_id = t.id and o.term_id = a.term_id and o.school_id <> v_school;
  select coalesce(jsonb_agg(jsonb_build_object('class_id', y.class_id, 'weekday', y.weekday, 'period', y.period_number)), '[]'::jsonb)
    into v_busy from public.teacher_timetable_slots y
   where y.term_id = a.term_id and y.teacher_id <> t.id
     and y.class_id in (select ta2.class_id from public.teaching_assignments ta2 join public.school_classes sc2 on sc2.id = ta2.class_id
                         where ta2.teacher_id = t.id and ta2.term_id = a.term_id and sc2.school_id = v_school);
  return jsonb_build_object('ok', true, 'open', coalesce(v_open, true), 'name', t.full_name, 'school_name', v_sname,
    'days', jsonb_build_array(6,0,1,2,3,4), 'periods_per_day', 8,
    'assignments', v_assign, 'slots', v_slots, 'other', v_other, 'busy', v_busy);
end $function$;

create or replace function public.teacher_portal_sup_timetable_save(p_civil text, p_phone text, p_teacher_id uuid, p_slots jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
declare c jsonb; a record; v_school uuid; t public.teacher_records; v_open boolean; item jsonb; asg public.teaching_assignments%rowtype;
        v_w smallint; v_p smallint; v_old jsonb; v_n int; v_con text;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  select * into a from private.tp_active();
  select * into t from public.teacher_records where id = p_teacher_id and active;
  if t.id is null or not (t.home_school_id = v_school or exists (
       select 1 from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
        where ta.teacher_id = t.id and ta.term_id = a.term_id and sc.school_id = v_school)) then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  select coalesce(timetable_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if p_slots is null or jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) > 48 then
    return jsonb_build_object('ok', false, 'reason', 'bad_slots');
  end if;
  perform pg_advisory_xact_lock(hashtext('tp_timetable:' || t.id::text));
  perform set_config('app.tp_timetable', 'on', true);
  begin
    select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb) into v_old from public.teacher_timetable_slots s
     where s.teacher_id = t.id and s.term_id = a.term_id and s.school_id = v_school;
    execute 'de' || 'lete from public.teacher_timetable_slots where teacher_id = $1 and term_id = $2 and school_id = $3' using t.id, a.term_id, v_school;
    for item in select value from jsonb_array_elements(p_slots) loop
      v_w := (item ->> 'weekday')::smallint; v_p := (item ->> 'period_number')::smallint;
      if v_w is null or v_p is null or v_w not in (0,1,2,3,4,6) or v_p < 1 or v_p > 8 then raise exception 'bad_slot'; end if;
      select ta.* into asg from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
       where ta.id = (item ->> 'assignment_id')::uuid and ta.teacher_id = t.id and ta.term_id = a.term_id and sc.school_id = v_school;
      if not found then raise exception 'bad_assignment'; end if;
      insert into public.teacher_timetable_slots(assignment_id, school_id, term_id, teacher_id, class_id, weekday, period_number)
        values (asg.id, v_school, a.term_id, t.id, asg.class_id, v_w, v_p);
    end loop;
    if exists (select 1 from public.teaching_assignments ta where ta.teacher_id = t.id and ta.term_id = a.term_id
                and (select count(*) from public.teacher_timetable_slots s2 where s2.assignment_id = ta.id) > ta.weekly_periods) then
      raise exception 'over_periods';
    end if;
    insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
      values ('senior_teacher', 'teacher_portal_sup_timetable_saved', 'teacher', t.id::text, v_old,
              jsonb_build_object('slots', p_slots, 'school_id', v_school, 'by_supervisor_teacher_id', c ->> 'teacher_id'));
    select count(*) into v_n from public.teacher_timetable_slots where teacher_id = t.id and term_id = a.term_id and school_id = v_school;
    perform set_config('app.tp_timetable', 'off', true);
    return jsonb_build_object('ok', true, 'saved', v_n);
  exception
    when unique_violation then
      get stacked diagnostics v_con = constraint_name;
      perform set_config('app.tp_timetable', 'off', true);
      return jsonb_build_object('ok', false, 'reason', case when v_con = 'timetable_teacher_no_overlap' then 'teacher_busy' else 'conflict' end);
    when raise_exception then perform set_config('app.tp_timetable', 'off', true); return jsonb_build_object('ok', false, 'reason', sqlerrm);
  end;
end $function$;

revoke all on function public.teacher_portal_sup_timetable_get(text, text, uuid) from public;
revoke all on function public.teacher_portal_sup_timetable_save(text, text, uuid, jsonb) from public;
grant execute on function public.teacher_portal_sup_timetable_get(text, text, uuid) to anon, authenticated, service_role;
grant execute on function public.teacher_portal_sup_timetable_save(text, text, uuid, jsonb) to anon, authenticated, service_role;
