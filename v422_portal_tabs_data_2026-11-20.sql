-- v422 بوابة المعلمين بتبويبات — المرحلة 1 (قاعدة البيانات) — 2026-11-20
-- (1) سبعة أعمدة جديدة في teacher_records يدخلها المعلم من البوابة (الفارغ فقط):
--     religion, nationality, marital_status, qualification_type, qualification_issuer, qualification_grade, qualification_date
-- (2) teacher_portal_fill_missing تقبلها، وteacher_portal_lookup تُرجعها (+ cadre_specialty وis_senior_teacher ومرحلة المدرسة)
-- (3) teacher_portal_sup_school تُرجعها لمعلمي المدرسة الأصليين (+ cadre_specialty)
-- (4) دالة قراءة جديدة teacher_portal_sup_timetable_overview (متابعة جداول معلمي مدرسة المشرف + شبكة جدول المدرسة)
-- التعديل نصي مرة واحدة لكل موضع على النص المخزن (يفشل إن لم يطابق مرة واحدة بالضبط).

create table if not exists private.v422_backup_functions (fn text primary key, def text not null, saved_at timestamptz default now());
insert into private.v422_backup_functions(fn, def)
select p.proname, pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('teacher_portal_lookup','teacher_portal_fill_missing','teacher_portal_sup_school')
on conflict (fn) do nothing;

alter table public.teacher_records
  add column if not exists religion text,
  add column if not exists nationality text,
  add column if not exists marital_status text,
  add column if not exists qualification_type text,
  add column if not exists qualification_issuer text,
  add column if not exists qualification_grade text,
  add column if not exists qualification_date date;

do $m$
declare
  fn text; d text; o text; r text; k int;
  edits text[][] := array[
    -- fill_missing: المتغيرات
    ['teacher_portal_fill_missing',
     $a$n_code text;$a$,
     $a$n_code text; n_rel text; n_nat text; n_mar text; n_qtype text; n_qiss text; n_qgr text; n_qdate date;$a$],
    -- fill_missing: الحقول الجديدة قبل else continue
    ['teacher_portal_fill_missing',
     $a$      else
        continue;
      end if;$a$,
     $a$      elsif k = 'religion' and coalesce(t.religion, '') = '' then
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
      end if;$a$],
    -- fill_missing: الكتابة
    ['teacher_portal_fill_missing',
     $a$teacher_code = coalesce(n_code, teacher_code)$a$,
     $a$teacher_code = coalesce(n_code, teacher_code),
    religion = coalesce(n_rel, religion), nationality = coalesce(n_nat, nationality), marital_status = coalesce(n_mar, marital_status),
    qualification_type = coalesce(n_qtype, qualification_type), qualification_issuer = coalesce(n_qiss, qualification_issuer),
    qualification_grade = coalesce(n_qgr, qualification_grade), qualification_date = coalesce(n_qdate, qualification_date)$a$],
    -- lookup: الحقول
    ['teacher_portal_lookup',
     $a$'teacher_code', t.teacher_code, 'work_type', t.work_type) end,$a$,
     $a$'teacher_code', t.teacher_code, 'work_type', t.work_type,
        'cadre_specialty', t.cadre_specialty, 'is_senior_teacher', coalesce(t.is_senior_teacher, false),
        'religion', t.religion, 'nationality', t.nationality, 'marital_status', t.marital_status,
        'qualification_type', t.qualification_type, 'qualification_issuer', t.qualification_issuer,
        'qualification_grade', t.qualification_grade, 'qualification_date', t.qualification_date) end,$a$],
    -- lookup: مرحلة المدرسة
    ['teacher_portal_lookup',
     $a$jsonb_build_object('id', s.id, 'name', s.name, 'stage_key',$a$,
     $a$jsonb_build_object('id', s.id, 'name', s.name, 'stage', s.stage, 'stage_key',$a$],
    -- sup_school: الحقول لمعلمي المدرسة الأصليين
    ['teacher_portal_sup_school',
     $a$'work_start_date', t.work_start_date)$a$,
     $a$'work_start_date', t.work_start_date,
           'cadre_specialty', t.cadre_specialty, 'religion', t.religion, 'nationality', t.nationality, 'marital_status', t.marital_status,
           'qualification_type', t.qualification_type, 'qualification_issuer', t.qualification_issuer,
           'qualification_grade', t.qualification_grade, 'qualification_date', t.qualification_date)$a$],
    -- sup_school: مرحلة المدرسة
    ['teacher_portal_sup_school',
     $a$jsonb_build_object('id', sch.id, 'name', sch.name, 'stage_key',$a$,
     $a$jsonb_build_object('id', sch.id, 'name', sch.name, 'stage', sch.stage, 'stage_key',$a$]
  ];
  defs jsonb := '{}'::jsonb;
  i int;
begin
  for i in 1 .. array_length(edits, 1) loop
    fn := edits[i][1]; o := edits[i][2]; r := edits[i][3];
    if defs ? fn then d := defs ->> fn;
    else
      select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = fn;
    end if;
    k := (length(d) - length(replace(d, o, ''))) / length(o);
    if k <> 1 then raise exception 'v422: % edit % matched % times', fn, i, k; end if;
    d := replace(d, o, r);
    defs := jsonb_set(defs, array[fn], to_jsonb(d), true);
  end loop;
  for fn in select jsonb_object_keys(defs) loop
    execute defs ->> fn;
  end loop;
end
$m$;

-- (4) متابعة جداول معلمي المدرسة للمشرف (قراءة فقط)
create or replace function public.teacher_portal_sup_timetable_overview(p_civil text, p_phone text)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $f$
declare c jsonb; a record; v_school uuid; sch record; v_teachers jsonb; v_slots jsonb; v_assign jsonb;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  select * into a from private.tp_active();
  select id, name, stage into sch from public.schools where id = v_school;

  -- المعلمون: أصليون نشطون أو لهم إسناد في المدرسة، بلا المجازين (renewed في العام النشط؛ قاعدة v374/v379)
  with tt as (
    select t.id, t.full_name, t.work_type, coalesce(t.home_school_id = v_school, false) as is_home
      from public.teacher_records t
     where t.active
       and (t.home_school_id = v_school or exists (
             select 1 from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
              where ta.teacher_id = t.id and ta.term_id = a.term_id and sc.school_id = v_school))
       and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id = l.academic_year_id and ay.is_active
                        where l.teacher_id = t.id and l.renewal_status = 'renewed')
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', tt.id, 'full_name', tt.full_name, 'work_type', tt.work_type, 'is_home', tt.is_home,
           'required', (select coalesce(sum(ta.weekly_periods), 0)::int from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
                         where ta.teacher_id = tt.id and ta.term_id = a.term_id and sc.school_id = v_school),
           'entered', (select count(*)::int from public.teacher_timetable_slots x
                        where x.teacher_id = tt.id and x.term_id = a.term_id and x.school_id = v_school))
         order by tt.full_name), '[]'::jsonb)
    into v_teachers from tt;

  select coalesce(jsonb_agg(jsonb_build_object(
           'assignment_id', ta.id, 'teacher_id', ta.teacher_id, 'class_id', ta.class_id,
           'grade_order', sc.grade_order, 'grade_label', private.tp_class_grade_label(sc.stage, sc.grade),
           'class_label', private.tp_class_name_label(sc.class_name), 'class_name', sc.class_name,
           'subject', cs.subject_name, 'periods', ta.weekly_periods,
           'placed', (select count(*)::int from public.teacher_timetable_slots x where x.assignment_id = ta.id))
         order by sc.grade_order nulls last, sc.class_name), '[]'::jsonb)
    into v_assign
    from public.teaching_assignments ta
    join public.school_classes sc on sc.id = ta.class_id
    left join public.curriculum_subjects cs on cs.id = ta.subject_id
   where ta.term_id = a.term_id and sc.school_id = v_school and ta.weekly_periods > 0;

  select coalesce(jsonb_agg(jsonb_build_object(
           'assignment_id', x.assignment_id, 'teacher_id', x.teacher_id, 'class_id', x.class_id,
           'weekday', x.weekday, 'period', x.period_number)), '[]'::jsonb)
    into v_slots
    from public.teacher_timetable_slots x
   where x.term_id = a.term_id and x.school_id = v_school;

  return jsonb_build_object('ok', true,
    'school', jsonb_build_object('id', sch.id, 'name', sch.name, 'stage', sch.stage),
    'days', jsonb_build_array(6,0,1,2,3,4), 'periods_per_day', 8,
    'teachers', v_teachers, 'assignments', v_assign, 'slots', v_slots);
end
$f$;

revoke all on function public.teacher_portal_sup_timetable_overview(text, text) from public;
grant execute on function public.teacher_portal_sup_timetable_overview(text, text) to anon, authenticated;
