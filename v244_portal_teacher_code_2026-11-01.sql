-- v244 (2026-11-01): بوابة المعلمين — المعلم يكتب «كود المعلم» في بياناته (بطلب المستخدم «أ»)
-- 1) private.tp_pkeys: يضم teacher_code (فيعرضه الاعتماد ويطبّقه عند تحديث معلم مسجّل).
-- 2) private.tp_apply_core: المعلم الجديد يُدرج بكوده إن كتبه.
-- 3) public.teacher_portal_submit: old_d يضم الكود؛ الكود أرقام فقط (6–8، الأرقام العربية تُحوَّل)، ولا يُقبل كود مسجّل لمعلم آخر نشط (code_taken).
-- مسار مشرف المدرسة بلا تغيير (tp_clean_person لا يقبل الكود). النسخ الأصلية في private.v244_backup (لا تُحذف).
-- الاسترجاع: rollback_v244_portal_teacher_code_2026-11-01.sql

create table if not exists private.v244_backup (fn text primary key, def text not null, saved_at timestamptz not null default now());
revoke all on private.v244_backup from public, anon, authenticated;

create or replace function pg_temp.v244_rep(src text, old text, new text) returns text language plpgsql as $f$
declare cnt int := (length(src) - length(replace(src, old, ''))) / length(old);
begin
  if cnt <> 1 then raise exception 'v244: النمط موجود % مرة: %', cnt, left(old, 80); end if;
  return replace(src, old, new);
end $f$;

do $v244$
declare f text; d text;
begin
  foreach f in array array['private.tp_pkeys()','private.tp_apply_core(text,uuid,boolean,boolean,jsonb)','public.teacher_portal_submit(text,text,text,jsonb)'] loop
    insert into private.v244_backup(fn, def) values (f, pg_get_functiondef(f::regprocedure)) on conflict (fn) do nothing;
  end loop;

  d := pg_get_functiondef('private.tp_pkeys()'::regprocedure);
  d := pg_temp.v244_rep(d, $o$'appointment_date','grade_acquired_date','work_start_date']$o$,
                           $n$'appointment_date','grade_acquired_date','work_start_date','teacher_code']$n$);
  execute d;

  d := pg_get_functiondef('private.tp_apply_core(text,uuid,boolean,boolean,jsonb)'::regprocedure);
  d := pg_temp.v244_rep(d, $o$work_type, home_school_id, active, source_reference)$o$,
                           $n$work_type, home_school_id, active, source_reference, teacher_code)$n$);
  d := pg_temp.v244_rep(d, $o$wt, s.school_id, true, 'بوابة المعلمين ' || s.ref)$o$,
                           $n$wt, s.school_id, true, 'بوابة المعلمين ' || s.ref, nullif(c ->> 'teacher_code', ''))$n$);
  execute d;

  d := pg_get_functiondef('public.teacher_portal_submit(text,text,text,jsonb)'::regprocedure);
  d := pg_temp.v244_rep(d, $o$'grade_acquired_date', t.grade_acquired_date, 'work_start_date', t.work_start_date);$o$,
                           $n$'grade_acquired_date', t.grade_acquired_date, 'work_start_date', t.work_start_date, 'teacher_code', t.teacher_code);$n$);
  d := pg_temp.v244_rep(d, $o$  v := nullif(btrim(coalesce(person ->> 'qualification_year', '')), '');$o$,
                           $n$  -- v244: كود المعلم (أرقام فقط 6–8، ولا يتكرر لمعلم آخر نشط)
  v := nullif(private.tp_digits(coalesce(person ->> 'teacher_code', '')), '');
  if v is not null and not (p_kind = 'update' and v = coalesce(private.tp_digits(old_d ->> 'teacher_code'), '')) then
    if v !~ '^[0-9]{6,8}$' then return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', 'teacher_code'); end if;
    if exists (select 1 from public.teacher_records x where x.active and private.tp_digits(x.teacher_code) = v and x.civil_id is distinct from v_civil) then
      return jsonb_build_object('ok', false, 'reason', 'code_taken', 'field', 'teacher_code');
    end if;
    clean := clean || jsonb_build_object('teacher_code', v);
  end if;
  v := nullif(btrim(coalesce(person ->> 'qualification_year', '')), '');$n$);
  execute d;
end $v244$;
