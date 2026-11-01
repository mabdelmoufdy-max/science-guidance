-- v242 (2026-11-01): بوابة المعلمين — لا طلب بدون فصول، ولا اختيار فصل مسند لمعلم آخر (بطلب المستخدم «نفذ أ»)
-- 1) teacher_portal_submit: رفض «no_classes» إن خلا الطلب من فصول المدرسة وفصول الانتداب (المرسلة أو القائمة غير المرسلة)،
--    وفحص فصول الانتداب بـ tp_subject_gate (taken / pending_taken) كفصول المدرسة.
-- 2) teacher_portal_sup_submit: فحص كل فصل بـ tp_subject_gate (فصول المعلم نفسه مسموحة) ورفض «no_classes».
-- 3) teacher_portal_classes_v2: الفصل المسند للمعلم صاحب الرقم القومي نفسه لا يظهر مقفولًا له.
-- التعديل بمطابقة نصية مرة واحدة على النص المخزن. النسخ الأصلية في private.v242_backup (لا تُحذف).
-- الاسترجاع: rollback_v242_portal_require_unassigned_classes_2026-11-01.sql

create table if not exists private.v242_backup (fn text primary key, def text not null, saved_at timestamptz not null default now());
revoke all on private.v242_backup from public, anon, authenticated;

create or replace function pg_temp.v242_rep(src text, old text, new text) returns text language plpgsql as $f$
declare cnt int := (length(src) - length(replace(src, old, ''))) / length(old);
begin
  if cnt <> 1 then raise exception 'v242: النمط موجود % مرة: %', cnt, left(old, 80); end if;
  return replace(src, old, new);
end $f$;

do $v242$
declare f text; d text;
begin
  foreach f in array array['public.teacher_portal_submit(text,text,text,jsonb)',
    'public.teacher_portal_sup_submit(text,text,text,uuid,uuid,jsonb,text)','public.teacher_portal_classes_v2(uuid,text)'] loop
    insert into private.v242_backup(fn, def) values (f, pg_get_functiondef(f::regprocedure)) on conflict (fn) do nothing;
  end loop;

  -- 1) إرسال المعلم
  d := pg_get_functiondef('public.teacher_portal_submit(text,text,text,jsonb)'::regprocedure);
  d := pg_temp.v242_rep(d, $o$if per is null or per < 1 or per > maxp then return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', 'deleg_classes'); end if;$o$,
    $n$if per is null or per < 1 or per > maxp then return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', 'deleg_classes'); end if;
        v_chk := private.tp_subject_gate(cid, null, t.id, v_civil, a.term_id); -- v242
        if v_chk in ('taken', 'pending_taken') then return jsonb_build_object('ok', false, 'reason', v_chk, 'field', 'deleg_classes', 'class_id', cid); end if;$n$);
  d := pg_temp.v242_rep(d, $o$changed := array(select jsonb_object_keys(clean));$o$,
    $n$-- v242: لا طلب بدون فصول (فصول المدرسة، أو فصول انتداب مرسلة، أو فصول انتداب قائمة لم تُرسل)
  if jsonb_array_length(v_cls) = 0
     and not exists (select 1 from jsonb_array_elements(v_dsch) s where jsonb_array_length(coalesce(s -> 'new', '[]'::jsonb)) > 0)
     and not (p_kind = 'update' and exists (
           select 1 from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
            where ta.teacher_id = t.id and ta.term_id = a.term_id and sc.school_id <> sch.id
              and sc.school_id is distinct from t.home_school_id
              and exists (select 1 from public.delegations dg where dg.teacher_id = t.id and dg.active and dg.to_school_id = sc.school_id)
              and not exists (select 1 from jsonb_array_elements(v_dsch) s where s ->> 'school_id' = sc.school_id::text))) then
    return jsonb_build_object('ok', false, 'reason', 'no_classes', 'field', 'classes');
  end if;
  changed := array(select jsonb_object_keys(clean));$n$);
  execute d;

  -- 2) إرسال مشرف المدرسة
  d := pg_get_functiondef('public.teacher_portal_sup_submit(text,text,text,uuid,uuid,jsonb,text)'::regprocedure);
  d := pg_temp.v242_rep(d, $o$v_in_school boolean;$o$, $n$v_in_school boolean; v_chk text; -- v242$n$);
  d := pg_temp.v242_rep(d, $o$if per is null or per < 1 or per > maxp then return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', 'classes'); end if;$o$,
    $n$if per is null or per < 1 or per > maxp then return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', 'classes'); end if;
      v_chk := private.tp_subject_gate(cid, null, case when p_kind = 'update' then t.id end, v_civil, a.term_id); -- v242
      if v_chk in ('taken', 'pending_taken') then return jsonb_build_object('ok', false, 'reason', v_chk, 'field', 'classes', 'class_id', cid); end if;$n$);
  d := pg_temp.v242_rep(d, $o$changed := array(select jsonb_object_keys(clean));$o$,
    $n$if jsonb_array_length(coalesce(v_cls, '[]'::jsonb)) = 0 then return jsonb_build_object('ok', false, 'reason', 'no_classes', 'field', 'classes'); end if; -- v242
  changed := array(select jsonb_object_keys(clean));$n$);
  execute d;

  -- 3) فصول المدرسة للمعلم: فصله هو لا يُقفل عليه
  d := pg_get_functiondef('public.teacher_portal_classes_v2(uuid,text)'::regprocedure);
  d := pg_temp.v242_rep(d, $o$count(*) filter (where x.taken_id is null and x.hold_name is null) as nfree,$o$,
    $n$count(*) filter (where (x.taken_id is null or x.taken_civil = private.tp_digits(p_civil)) and x.hold_name is null) as nfree, -- v242$n$);
  d := pg_temp.v242_rep(d, $o$ta2.teacher_id as taken_id, tr.full_name as taken_name,$o$,
    $n$ta2.teacher_id as taken_id, tr.full_name as taken_name, tr.civil_id as taken_civil,$n$);
  execute d;
end $v242$;
