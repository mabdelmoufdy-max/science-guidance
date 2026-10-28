-- يعيد دوال الإرسال والمعاينة والتطبيق وكشف التعارض إلى ما قبل v215 (تبديل عكسي دقيق) ثم يحذف الإضافات.
-- شغّله من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
create or replace function pg_temp.r1(src text, new text, old text) returns text language plpgsql as $f$
begin
  if (length(src) - length(replace(src, old, ''))) / length(old) <> 1 then raise exception 'pattern not found exactly once: %', left(old, 60); end if;
  return replace(src, old, new);
end $f$;
do $m$
declare d text;
begin
  d := pg_get_functiondef('public.teacher_portal_submit(text,text,text,jsonb)'::regprocedure);
  d := pg_temp.r1(d, $q$  v_school uuid; v_cls jsonb := '[]'::jsonb;$q$, $q$  v_choices jsonb := '{}'::jsonb; v_subj uuid; v_chk text;
  v_school uuid; v_cls jsonb := '[]'::jsonb;$q$);
  d := pg_temp.r1(d, $q$  -- الفصول
  for item in select * from jsonb_array_elements(case when jsonb_typeof(p_payload -> 'classes') = 'array'$q$, $q$  -- الفصول
  perform pg_advisory_xact_lock(hashtext('tp_class_hold:' || sch.id::text));
  for item in select * from jsonb_array_elements(case when jsonb_typeof(p_payload -> 'classes') = 'array'$q$);
  d := pg_temp.r1(d, $q$    v_seen := v_seen || cid;
    v_cls := v_cls ||$q$, $q$    begin v_subj := nullif(item ->> 'subject_id', '')::uuid; exception when others then v_subj := null; end;
    v_chk := private.tp_subject_gate(cid, v_subj, case when p_kind = 'update' then t.id end, v_civil, a.term_id);
    if v_chk not in ('ok', 'ok_choice') then
      return jsonb_build_object('ok', false, 'reason', v_chk, 'field', 'classes', 'class_id', cid);
    end if;
    if v_chk = 'ok_choice' then v_choices := v_choices || jsonb_build_object(cid::text, v_subj); end if;
    v_seen := v_seen || cid;
    v_cls := v_cls ||$q$);
  d := pg_temp.r1(d, $q$changed_fields, school_changed, classes_changed, unchanged, deleg)$q$, $q$changed_fields, school_changed, classes_changed, unchanged, deleg, subject_choices)$q$);
  d := pg_temp.r1(d, $q$old_d, new_d, old_cls, v_cls, changed, v_school_changed, v_cls_changed, v_unchanged, v_deleg);$q$, $q$old_d, new_d, old_cls, v_cls, changed, v_school_changed, v_cls_changed, v_unchanged, v_deleg,
      nullif(v_choices, '{}'::jsonb));$q$);
  execute d;
  d := pg_get_functiondef('public.teacher_portal_admin_preview(text,uuid,jsonb)'::regprocedure);
  d := pg_temp.r1(d, $q$s.new_classes, coalesce(opts -> 'choices', '{}'::jsonb));$q$, $q$s.new_classes, coalesce(s.subject_choices, '{}'::jsonb) || coalesce(opts -> 'choices', '{}'::jsonb));$q$);
  execute d;
  d := pg_get_functiondef('private.tp_apply_core(text,uuid,boolean,boolean,jsonb)'::regprocedure);
  d := pg_temp.r1(d, $q$plan := private.tp_class_plan(tid, s.school_id, s.term_id, s.new_classes, coalesce(p_opts -> 'choices', '{}'::jsonb));$q$, $q$plan := private.tp_class_plan(tid, s.school_id, s.term_id, s.new_classes, coalesce(s.subject_choices, '{}'::jsonb) || coalesce(p_opts -> 'choices', '{}'::jsonb));$q$);
  execute d;
  d := pg_get_functiondef('private.tp_conflict_blockers(text,uuid)'::regprocedure);
  d := pg_temp.r1(d, $q$s.new_classes, '{}'::jsonb);$q$, $q$s.new_classes, coalesce(s.subject_choices, '{}'::jsonb));$q$);
  execute d;
end $m$;
-- بعد ما سبق يمكن حذف الإضافات (اختياري): العمود subject_choices والدوال الجديدة والعرض يعود كما كان
drop function if exists public.teacher_portal_classes_v2(uuid, text);
drop function if exists private.tp_subject_gate(uuid, uuid, uuid, text, uuid);
drop function if exists private.tp_pending_holds(uuid, text);
