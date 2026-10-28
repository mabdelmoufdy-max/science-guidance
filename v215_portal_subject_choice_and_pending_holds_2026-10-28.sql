-- v215 (2026-10-28، بطلب المستخدم): منع تكرار اختيار المجموعة/المادة أثناء التسجيل في بوابة المعلمين
--   1) الطلبات المعلّقة تُحتسب كحجز (تعطيل الفصل/المادة لمعلم آخر حتى يُبتّ في الطلب)
--   2) اختيار المادة داخل البوابة (كل معلم يدرّس مادة واحدة): المادة تُحفظ في عمود جديد subject_choices
--      (new_classes لم يتغيّر شكله) وتُستخدم افتراضيًا عند الاعتماد
--   3) رفض الطلب عند الإرسال إن كانت المادة مسندة أو محجوزة بطلب معلّق (مع قفل لكل مدرسة لمنع التزامن)
-- لا يمس الإسنادات ولا الطلبات القائمة. الاسترجاع: rollback_v215_*.sql

alter table public.teacher_portal_submissions add column if not exists subject_choices jsonb;

create or replace view private.tp_all_submissions as
 SELECT 'teacher'::text AS source, s.id, s.ref, s.kind, s.status, s.teacher_id, s.civil_id, s.school_id,
    s.academic_year_id, s.term_id, s.old_data, s.new_data, s.old_classes, s.new_classes, s.changed_fields,
    s.school_changed, s.classes_changed, s.unchanged, NULL::uuid AS supervisor_id, NULL::text AS supervisor_civil,
    s.created_at, s.reviewed_at, s.reviewed_by, s.review_note, s.deleg, s.subject_choices
   FROM teacher_portal_submissions s
 UNION ALL
 SELECT 'supervisor'::text AS source, s.id, s.ref, s.kind, s.status, s.teacher_id, s.civil_id, s.school_id,
    s.academic_year_id, s.term_id, s.old_data, s.new_data, s.old_classes, s.new_classes, s.changed_fields,
    false AS school_changed, s.classes_changed, false AS unchanged, s.supervisor_id, s.supervisor_civil,
    s.created_at, s.reviewed_at, s.reviewed_by, s.review_note, NULL::jsonb AS deleg, NULL::jsonb AS subject_choices
   FROM teacher_portal_sup_submissions s;

-- الحجوزات الناتجة عن الطلبات المعلّقة (فصل + مادة + اسم صاحب الطلب)، دون طلبات الرقم المدني المستثنى
create or replace function private.tp_pending_holds(p_term uuid, p_civil text default null)
returns table(class_id uuid, subject_id uuid, holder text)
language sql stable security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $f$
  with pend as (
    select s.civil_id, s.new_classes, s.subject_choices,
           coalesce(tr.full_name, s.new_data ->> 'full_name', 'معلم آخر') as nm
      from private.tp_all_submissions s
      left join public.teacher_records tr on tr.id = s.teacher_id
     where s.status = 'pending' and s.term_id = p_term
       and (p_civil is null or s.civil_id is distinct from p_civil)
  ), it as (
    select p.civil_id, p.nm, p.subject_choices, (x ->> 'class_id')::uuid as class_id
      from pend p,
           jsonb_array_elements(case when jsonb_typeof(p.new_classes) = 'array' then p.new_classes else '[]'::jsonb end) x
  ), subs as (
    select i.class_id, r.subject_id, i.nm, i.subject_choices,
           count(*) over (partition by i.civil_id, i.class_id) as n_sub
      from it i
      join public.school_classes sc on sc.id = i.class_id
      join public.class_subject_requirements r on r.class_id = i.class_id and coalesce(r.weekly_periods, 0) > 0
      join public.curriculum_subjects cs
        on cs.id = r.subject_id and cs.active and cs.subject_group = 'science' and cs.stage = sc.stage
       and public.normalize_science_grade(cs.grade) = public.normalize_science_grade(sc.grade)
  )
  select class_id, subject_id, nm from subs
   where (subject_choices ->> class_id::text) = subject_id::text
      or (nullif(subject_choices ->> class_id::text, '') is null and n_sub = 1);
$f$;

-- بوابة التحقق من اختيار فصل/مادة عند الإرسال: ok | ok_choice (مادة مختارة تُحفظ) | سبب الرفض
create or replace function private.tp_subject_gate(p_class uuid, p_subject uuid, p_teacher uuid, p_civil text, p_term uuid)
returns text
language plpgsql stable security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $f$
declare n int; sid uuid; ok_sub boolean;
begin
  -- فصل يملكه المعلم أصلًا: يبقى كما هو
  if p_teacher is not null and exists (select 1 from public.teaching_assignments ta
       where ta.teacher_id = p_teacher and ta.class_id = p_class and ta.term_id = p_term) then
    return 'ok';
  end if;
  select count(*), min(r.subject_id::text)::uuid into n, sid
    from public.class_subject_requirements r
    join public.school_classes sc on sc.id = r.class_id
    join public.curriculum_subjects cs
      on cs.id = r.subject_id and cs.active and cs.subject_group = 'science' and cs.stage = sc.stage
     and public.normalize_science_grade(cs.grade) = public.normalize_science_grade(sc.grade)
   where r.class_id = p_class and coalesce(r.weekly_periods, 0) > 0;
  if n = 0 then return 'ok'; end if;
  if n = 1 then p_subject := sid;
  else
    if p_subject is null then return 'subject_required'; end if;
    select exists (select 1 from public.class_subject_requirements r
                    join public.school_classes sc on sc.id = r.class_id
                    join public.curriculum_subjects cs
                      on cs.id = r.subject_id and cs.active and cs.subject_group = 'science' and cs.stage = sc.stage
                     and public.normalize_science_grade(cs.grade) = public.normalize_science_grade(sc.grade)
                   where r.class_id = p_class and r.subject_id = p_subject and coalesce(r.weekly_periods, 0) > 0)
      into ok_sub;
    if not ok_sub then return 'invalid_subject'; end if;
  end if;
  if exists (select 1 from public.teaching_assignments ta
              where ta.class_id = p_class and ta.subject_id = p_subject and ta.term_id = p_term
                and ta.teacher_id is distinct from p_teacher) then
    return 'taken';
  end if;
  if exists (select 1 from private.tp_pending_holds(p_term, p_civil) h
              where h.class_id = p_class and h.subject_id = p_subject) then
    return 'pending_taken';
  end if;
  return case when n > 1 then 'ok_choice' else 'ok' end;
end $f$;

-- عرض فصول المدرسة للبوابة مع المواد والحجز بالإسناد أو بطلب معلّق (p_civil: يُستثنى طلب صاحبه نفسه)
create or replace function public.teacher_portal_classes_v2(p_school_id uuid, p_civil text default null)
returns jsonb
language sql stable security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $f$
  with a as (select * from private.tp_active()),
  holds as (select h.* from a, private.tp_pending_holds(a.term_id, private.tp_digits(p_civil)) h)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', sc.id, 'grade_order', sc.grade_order,
           'grade_label', private.tp_class_grade_label(sc.stage, sc.grade),
           'class_label', private.tp_class_name_label(sc.class_name),
           'label', private.tp_class_grade_label(sc.stage, sc.grade) || ' – ' || private.tp_class_name_label(sc.class_name),
           'periods', sc.science_periods,
           'locked', coalesce(tk.nreq > 0 and tk.nfree = 0, false),
           'taken_by', coalesce(tk.names, '[]'::jsonb),
           'pending_by', coalesce(tk.pend, '[]'::jsonb),
           'subjects', coalesce(tk.subs, '[]'::jsonb))
         order by sc.grade_order nulls last, (substring(sc.class_name from '([0-9]+)\s*$'))::int nulls last, sc.class_name), '[]'::jsonb)
  from public.school_classes sc
  cross join a
  left join lateral (
    select count(*) as nreq,
           count(*) filter (where x.taken_id is null and x.hold_name is null) as nfree,
           jsonb_agg(distinct x.taken_name) filter (where x.taken_name is not null) as names,
           jsonb_agg(distinct x.hold_name) filter (where x.hold_name is not null and x.taken_id is null) as pend,
           jsonb_agg(jsonb_build_object('subject_id', x.subject_id, 'name', x.subject_name, 'periods', x.weekly_periods,
                                         'taken_by', x.taken_name, 'pending_by', case when x.taken_id is null then x.hold_name end)
                     order by x.sort_order, x.subject_name) as subs
      from (
        select r.subject_id, cs.subject_name, cs.sort_order, r.weekly_periods,
               ta2.teacher_id as taken_id, tr.full_name as taken_name,
               (select h.holder from holds h where h.class_id = r.class_id and h.subject_id = r.subject_id limit 1) as hold_name
          from public.class_subject_requirements r
          join public.curriculum_subjects cs
            on cs.id = r.subject_id and cs.active and cs.subject_group = 'science'
           and cs.stage = sc.stage
           and public.normalize_science_grade(cs.grade) = public.normalize_science_grade(sc.grade)
          left join public.teaching_assignments ta2
            on ta2.class_id = r.class_id and ta2.subject_id = r.subject_id and ta2.term_id = a.term_id
          left join public.teacher_records tr on tr.id = ta2.teacher_id
         where r.class_id = sc.id and coalesce(r.weekly_periods, 0) > 0
      ) x
  ) tk on true
  where sc.school_id = p_school_id and sc.term_id = a.term_id and sc.science_periods > 0
$f$;
grant execute on function public.teacher_portal_classes_v2(uuid, text) to anon, authenticated;

-- تعديل الدوال القائمة بتبديل نصي دقيق (مرة واحدة لكل موضع، وإلا يفشل التنفيذ)
create or replace function pg_temp.r1(src text, old text, new text) returns text language plpgsql as $f$
begin
  if (length(src) - length(replace(src, old, ''))) / length(old) <> 1 then
    raise exception 'pattern not found exactly once: %', left(old, 60);
  end if;
  return replace(src, old, new);
end $f$;

do $m$
declare d text; o oid;
begin
  -- الإرسال: اختيار المادة + فحص الحجز + قفل المدرسة
  o := 'public.teacher_portal_submit(text,text,text,jsonb)'::regprocedure;
  d := pg_get_functiondef(o);
  d := pg_temp.r1(d, $q$  v_school uuid; v_cls jsonb := '[]'::jsonb;$q$,
                     $q$  v_choices jsonb := '{}'::jsonb; v_subj uuid; v_chk text;
  v_school uuid; v_cls jsonb := '[]'::jsonb;$q$);
  d := pg_temp.r1(d, $q$  -- الفصول
  for item in select * from jsonb_array_elements(case when jsonb_typeof(p_payload -> 'classes') = 'array'$q$,
                     $q$  -- الفصول
  perform pg_advisory_xact_lock(hashtext('tp_class_hold:' || sch.id::text));
  for item in select * from jsonb_array_elements(case when jsonb_typeof(p_payload -> 'classes') = 'array'$q$);
  d := pg_temp.r1(d, $q$    v_seen := v_seen || cid;
    v_cls := v_cls ||$q$,
                     $q$    begin v_subj := nullif(item ->> 'subject_id', '')::uuid; exception when others then v_subj := null; end;
    v_chk := private.tp_subject_gate(cid, v_subj, case when p_kind = 'update' then t.id end, v_civil, a.term_id);
    if v_chk not in ('ok', 'ok_choice') then
      return jsonb_build_object('ok', false, 'reason', v_chk, 'field', 'classes', 'class_id', cid);
    end if;
    if v_chk = 'ok_choice' then v_choices := v_choices || jsonb_build_object(cid::text, v_subj); end if;
    v_seen := v_seen || cid;
    v_cls := v_cls ||$q$);
  d := pg_temp.r1(d, $q$changed_fields, school_changed, classes_changed, unchanged, deleg)$q$,
                     $q$changed_fields, school_changed, classes_changed, unchanged, deleg, subject_choices)$q$);
  d := pg_temp.r1(d, $q$old_d, new_d, old_cls, v_cls, changed, v_school_changed, v_cls_changed, v_unchanged, v_deleg);$q$,
                     $q$old_d, new_d, old_cls, v_cls, changed, v_school_changed, v_cls_changed, v_unchanged, v_deleg,
      nullif(v_choices, '{}'::jsonb));$q$);
  execute d;

  -- المعاينة: اختيار المعلم افتراضي، واختيار المنسق يتقدم عليه
  o := 'public.teacher_portal_admin_preview(text,uuid,jsonb)'::regprocedure;
  d := pg_get_functiondef(o);
  d := pg_temp.r1(d, $q$s.new_classes, coalesce(opts -> 'choices', '{}'::jsonb));$q$,
                     $q$s.new_classes, coalesce(s.subject_choices, '{}'::jsonb) || coalesce(opts -> 'choices', '{}'::jsonb));$q$);
  execute d;

  -- التطبيق عند الاعتماد
  o := 'private.tp_apply_core(text,uuid,boolean,boolean,jsonb)'::regprocedure;
  d := pg_get_functiondef(o);
  d := pg_temp.r1(d, $q$plan := private.tp_class_plan(tid, s.school_id, s.term_id, s.new_classes, coalesce(p_opts -> 'choices', '{}'::jsonb));$q$,
                     $q$plan := private.tp_class_plan(tid, s.school_id, s.term_id, s.new_classes, coalesce(s.subject_choices, '{}'::jsonb) || coalesce(p_opts -> 'choices', '{}'::jsonb));$q$);
  execute d;

  -- كشف التعارض في قائمة الاعتماد
  o := 'private.tp_conflict_blockers(text,uuid)'::regprocedure;
  d := pg_get_functiondef(o);
  d := pg_temp.r1(d, $q$s.new_classes, '{}'::jsonb);$q$,
                     $q$s.new_classes, coalesce(s.subject_choices, '{}'::jsonb));$q$);
  execute d;
end $m$;
