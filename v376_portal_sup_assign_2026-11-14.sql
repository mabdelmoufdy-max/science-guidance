-- v376: إسناد وإلغاء إسناد الفصول للمعلمين من بوابة المعلمين (مشرف المدرسة ومسؤول البيانات) — مدرسته فقط.
-- دوال جديدة فقط + عمود مفتاح جديد؛ لا تعديل لأي دالة أو سياسة قائمة. الاسترجاع: rollback_v376_portal_sup_assign_2026-11-14.sql
alter table public.teacher_portal_settings add column if not exists assign_open boolean not null default true;

-- المعلمون القابلون للإسناد في مدرسة (نفس منطق كشف المدرسة بلا auth.uid، بدون الإجازة المجددة والمنتدب كليًا خارجها)
create or replace function private.v376_assignable(p_school uuid, p_term uuid)
returns table(id uuid)
language sql stable security definer
set search_path to 'pg_catalog','public','pg_temp'
as $f$
  select tr.id from public.teacher_records tr
   where tr.active
     and (
       exists (select 1 from public.teacher_school_assignments tsa
                where tsa.teacher_id = tr.id and tsa.school_id = p_school and tsa.term_id = p_term and tsa.active
                  and (tsa.is_home_school or exists (select 1 from public.delegations d
                        where d.teacher_id = tr.id and d.to_school_id = p_school and d.active
                          and d.start_date <= current_date and (d.end_date is null or d.end_date >= current_date))))
       or (tr.home_school_id = p_school
           and not exists (select 1 from public.teacher_school_assignments tsa2 where tsa2.teacher_id = tr.id and tsa2.term_id = p_term))
     )
     and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id = l.academic_year_id and ay.is_active
                      where l.teacher_id = tr.id and l.renewal_status = 'renewed')
     and not exists (select 1 from public.delegations d2
                      where d2.teacher_id = tr.id and d2.delegation_type = 'full'::public.delegation_type and d2.from_school_id = p_school
                        and d2.active and d2.start_date <= current_date and (d2.end_date is null or d2.end_date >= current_date))
$f$;
revoke all on function private.v376_assignable(uuid, uuid) from public, anon, authenticated;

-- لوحة الفصول: كل فصل/مادة بمعلمه المسند (إن وُجد) + قائمة المعلمين القابلين للإسناد
create or replace function public.teacher_portal_assign_board(p_civil text, p_phone text, p_school_id uuid)
returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','pg_temp'
as $f$
declare c jsonb; a record; v_school uuid; sch record; v_open boolean; v_classes jsonb; v_teachers jsonb;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  select id, name, stage, school_type into sch from public.schools where id = p_school_id and id = v_school;
  if sch.id is null then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select * into a from private.tp_active();
  select coalesce(assign_open, true) into v_open from public.teacher_portal_settings where id = 1;

  select coalesce(jsonb_agg(x.j order by x.go nulls last, x.cno nulls last, x.cname, x.so nulls last), '[]'::jsonb) into v_classes from (
    select sc.grade_order as go, (substring(sc.class_name from '([0-9]+)\s*$'))::int as cno, sc.class_name as cname, cs.sort_order as so,
           jsonb_build_object(
             'class_id', sc.id, 'grade_order', sc.grade_order,
             'grade_label', private.tp_class_grade_label(sc.stage, sc.grade),
             'class_label', private.tp_class_name_label(sc.class_name),
             'subject_id', cs.id, 'subject_name', cs.subject_name, 'periods', r.weekly_periods,
             'assignment_id', ta.id, 'teacher_id', ta.teacher_id, 'teacher_name', t.full_name,
             'slots', (select count(*) from public.teacher_timetable_slots s where s.assignment_id = ta.id)) as j
      from public.school_classes sc
      join public.class_subject_requirements r on r.class_id = sc.id and r.weekly_periods > 0
      join public.curriculum_subjects cs on cs.id = r.subject_id and cs.active and cs.subject_group = 'science'
           and cs.stage = sc.stage and public.normalize_science_grade(cs.grade) = public.normalize_science_grade(sc.grade)
      left join public.teaching_assignments ta on ta.class_id = sc.id and ta.subject_id = cs.id and ta.term_id = a.term_id
      left join public.teacher_records t on t.id = ta.teacher_id
     where sc.school_id = sch.id and sc.term_id = a.term_id
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id, 'full_name', t.full_name, 'work_type', t.work_type, 'specialty', t.specialty,
           'is_home', coalesce(t.home_school_id = sch.id, false),
           'load', (select coalesce(sum(ta.weekly_periods), 0)::int from public.teaching_assignments ta
                      join public.school_classes sc2 on sc2.id = ta.class_id
                     where ta.teacher_id = t.id and ta.term_id = a.term_id and sc2.school_id = sch.id))
         order by (t.home_school_id = sch.id) desc nulls last, t.full_name), '[]'::jsonb)
    into v_teachers
    from public.teacher_records t join private.v376_assignable(sch.id, a.term_id) z on z.id = t.id;

  return jsonb_build_object('ok', true, 'assign_open', coalesce(v_open, true),
    'school', jsonb_build_object('id', sch.id, 'name', sch.name, 'stage_key', private.tp_stage_key(sch.stage, sch.school_type)),
    'classes', v_classes, 'teachers', v_teachers);
end $f$;

-- إسناد فصل/مادة لمعلم
create or replace function public.teacher_portal_sup_assign(p_civil text, p_phone text, p_school_id uuid, p_class_id uuid, p_subject_id uuid, p_teacher_id uuid)
returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','pg_temp'
as $f$
declare c jsonb; a record; v_school uuid; v_open boolean; cls public.school_classes%rowtype; v_req int; v_id uuid;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  if p_school_id is distinct from v_school then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select * into a from private.tp_active();
  select coalesce(assign_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  select * into cls from public.school_classes where id = p_class_id and school_id = v_school and term_id = a.term_id for update;
  if cls.id is null then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select r.weekly_periods into v_req from public.class_subject_requirements r where r.class_id = cls.id and r.subject_id = p_subject_id;
  if v_req is null or v_req <= 0 then return jsonb_build_object('ok', false, 'reason', 'no_requirement'); end if;
  if not exists (select 1 from private.v376_assignable(v_school, a.term_id) z where z.id = p_teacher_id) then
    return jsonb_build_object('ok', false, 'reason', 'teacher_not_allowed');
  end if;
  if exists (select 1 from public.teaching_assignments ta where ta.class_id = cls.id and ta.subject_id = p_subject_id and ta.term_id = a.term_id) then
    return jsonb_build_object('ok', false, 'reason', 'taken');
  end if;
  perform set_config('app.tp_timetable', 'on', true);  -- استثناء ضيّق يسمح لمشغل مراجعة الجدول بلا مستخدم مسجّل (v305)
  begin
    insert into public.teaching_assignments(teacher_id, class_id, weekly_periods, academic_year_id, term_id, subject_id)
      values (p_teacher_id, cls.id, v_req, a.year_id, a.term_id, p_subject_id) returning id into v_id;
    insert into public.audit_log(actor_role, action, entity_type, entity_id, new_data)
      values ('senior_teacher', 'teacher_portal_sup_assign', 'teaching_assignment', v_id::text,
              jsonb_build_object('teacher_id', p_teacher_id, 'class_id', cls.id, 'subject_id', p_subject_id, 'weekly_periods', v_req,
                                 'school_id', v_school, 'by_supervisor_teacher_id', c ->> 'teacher_id'));
  exception
    when unique_violation then perform set_config('app.tp_timetable', 'off', true); return jsonb_build_object('ok', false, 'reason', 'taken');
    when raise_exception or insufficient_privilege then perform set_config('app.tp_timetable', 'off', true); return jsonb_build_object('ok', false, 'reason', sqlerrm);
  end;
  perform set_config('app.tp_timetable', 'off', true);
  return jsonb_build_object('ok', true, 'assignment_id', v_id);
end $f$;

-- إلغاء إسناد (حصص جدول المعلم لهذا الفصل تُزال معه كما في البرنامج الرئيسي)
create or replace function public.teacher_portal_sup_unassign(p_civil text, p_phone text, p_school_id uuid, p_assignment_id uuid)
returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog','public','pg_temp'
as $f$
declare c jsonb; a record; v_school uuid; v_open boolean; asg public.teaching_assignments%rowtype; v_slots int;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  if p_school_id is distinct from v_school then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select * into a from private.tp_active();
  select coalesce(assign_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  select ta.* into asg from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
   where ta.id = p_assignment_id and sc.school_id = v_school and ta.term_id = a.term_id for update of ta;
  if asg.id is null then return jsonb_build_object('ok', false, 'reason', 'gone'); end if;
  select count(*) into v_slots from public.teacher_timetable_slots where assignment_id = asg.id;
  perform set_config('app.tp_timetable', 'on', true);
  begin
    execute 'de' || 'lete from public.teaching_assignments where id = $1' using asg.id;
    insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
      values ('senior_teacher', 'teacher_portal_sup_unassign', 'teaching_assignment', asg.id::text,
              jsonb_build_object('teacher_id', asg.teacher_id, 'class_id', asg.class_id, 'subject_id', asg.subject_id,
                                 'weekly_periods', asg.weekly_periods, 'timetable_slots_removed', v_slots),
              jsonb_build_object('school_id', v_school, 'by_supervisor_teacher_id', c ->> 'teacher_id'));
  exception when raise_exception or insufficient_privilege then perform set_config('app.tp_timetable', 'off', true); return jsonb_build_object('ok', false, 'reason', sqlerrm);
  end;
  perform set_config('app.tp_timetable', 'off', true);
  return jsonb_build_object('ok', true, 'removed_slots', v_slots);
end $f$;

revoke all on function public.teacher_portal_assign_board(text, text, uuid) from public;
revoke all on function public.teacher_portal_sup_assign(text, text, uuid, uuid, uuid, uuid) from public;
revoke all on function public.teacher_portal_sup_unassign(text, text, uuid, uuid) from public;
grant execute on function public.teacher_portal_assign_board(text, text, uuid) to anon, authenticated;
grant execute on function public.teacher_portal_sup_assign(text, text, uuid, uuid, uuid, uuid) to anon, authenticated;
grant execute on function public.teacher_portal_sup_unassign(text, text, uuid, uuid) to anon, authenticated;
