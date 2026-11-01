-- v243 (2026-11-01): بوابة المعلمين — الإعدادي والثانوي العام والصناعي: المعلم المسجل يعدّل بياناته الأساسية فقط
-- (بطلب المستخدم «يسمح للمعلم تعديل البيانات الأساسية ماعدا الرقم القومي ويمنع تعديل الحصص» ثم «نفذ أ»)
-- 1) teacher_portal_lookup: لا يُغلق التعديل لهذه المراحل (editing_open من الإعدادات)، ويعيد classes_locked + classes_note.
-- 2) teacher_portal_submit: تحديث معلم مرحلته مغلقة = بيانات أساسية فقط: تُتجاهل الفصول والانتداب والمدرسة من الطلب
--    (المدرسة = الأصلية، الفصول = الحالية بلا تغيير، classes_changed=false)، ولا تُطبَّق عليه قاعدة «لا طلب بدون فصول».
--    التسجيل الجديد لهذه المراحل والانتقال إليها يبقيان مغلقين. مشرف المدرسة بلا تغيير (للعرض فقط).
-- النسخ الأصلية في private.v243_backup (لا تُحذف). الاسترجاع: rollback_v243_portal_locked_stage_person_only_2026-11-01.sql

create table if not exists private.v243_backup (fn text primary key, def text not null, saved_at timestamptz not null default now());
revoke all on private.v243_backup from public, anon, authenticated;

create or replace function pg_temp.v243_rep(src text, old text, new text) returns text language plpgsql as $f$
declare cnt int := (length(src) - length(replace(src, old, ''))) / length(old);
begin
  if cnt <> 1 then raise exception 'v243: النمط موجود % مرة: %', cnt, left(old, 80); end if;
  return replace(src, old, new);
end $f$;

do $v243$
declare
  st constant text := $s$('إعدادي','ثانوي عام','ثانوي صناعي','ثانوي')$s$;
  f text; d text;
begin
  foreach f in array array['public.teacher_portal_lookup(text,text)','public.teacher_portal_submit(text,text,text,jsonb)'] loop
    insert into private.v243_backup(fn, def) values (f, pg_get_functiondef(f::regprocedure)) on conflict (fn) do nothing;
  end loop;

  -- 1) عرض المعلم
  d := pg_get_functiondef('public.teacher_portal_lookup(text,text)'::regprocedure);
  d := pg_temp.v243_rep(d, 'if s.stage in ' || st || ' then v_open := false; end if; -- v181 + v240',
    '-- v243: الإعدادي والثانوي: البيانات الأساسية قابلة للتعديل، والمدرسة والفصول للعرض فقط (classes_locked)');
  d := pg_temp.v243_rep(d, $o$'closed_note', private.tp_closed_note(s.stage),$o$,
    $n$'closed_note', private.tp_closed_note(s.stage),
    'classes_locked', coalesce(s.stage in $n$ || st || $n$, false),
    'classes_note', case when s.stage in $n$ || st || $n$ then replace(private.tp_closed_note(s.stage), 'للعرض فقط', 'المدرسة والفصول والحصص للعرض فقط') end,$n$);
  execute d;

  -- 2) إرسال المعلم
  d := pg_get_functiondef('public.teacher_portal_submit(text,text,text,jsonb)'::regprocedure);
  d := pg_temp.v243_rep(d, $o$v_subj uuid; v_chk text;$o$, $n$v_subj uuid; v_chk text; v_locked boolean := false; -- v243$n$);
  d := pg_temp.v243_rep(d,
    $o$  if exists (select 1 from public.teacher_records tp join public.schools sp on sp.id = tp.home_school_id where tp.civil_id = private.tp_digits(p_civil) and sp.stage in$o$,
    $n$  -- v243: تحديث معلم مرحلته مغلقة = البيانات الأساسية فقط (المدرسة الأصلية، بلا فصول ولا انتداب في الطلب)
  if p_kind = 'update' and exists (select 1 from public.teacher_records tp join public.schools sp on sp.id = tp.home_school_id
        where tp.civil_id = private.tp_digits(p_civil) and sp.stage in $n$ || st || $n$) then
    v_locked := true;
    p_payload := (p_payload - 'classes' - 'deleg_classes') || jsonb_build_object('school_id',
      (select tp.home_school_id::text from public.teacher_records tp join public.schools sp on sp.id = tp.home_school_id
        where tp.civil_id = private.tp_digits(p_civil) and sp.stage in $n$ || st || $n$ limit 1));
  end if;
  if not v_locked and (exists (select 1 from public.teacher_records tp join public.schools sp on sp.id = tp.home_school_id where tp.civil_id = private.tp_digits(p_civil) and sp.stage in$n$);
  d := pg_temp.v243_rep(d, $o$sp.id::text = nullif(p_payload ->> 'school_id', '')) then$o$,
    $n$sp.id::text = nullif(p_payload ->> 'school_id', ''))) then$n$);
  d := pg_temp.v243_rep(d, $o$  if jsonb_array_length(v_cls) = 0
     and not exists (select 1 from jsonb_array_elements(v_dsch)$o$,
    $n$  if not v_locked and jsonb_array_length(v_cls) = 0
     and not exists (select 1 from jsonb_array_elements(v_dsch)$n$);
  d := pg_temp.v243_rep(d, $o$    v_unchanged := cardinality(changed) = 0 and not v_school_changed and not v_cls_changed and not v_deleg_changed;$o$,
    $n$    if v_locked then v_cls := old_cls; v_cls_changed := false; v_school_changed := false; v_deleg := null; v_deleg_changed := false; end if; -- v243
    v_unchanged := cardinality(changed) = 0 and not v_school_changed and not v_cls_changed and not v_deleg_changed;$n$);
  execute d;
end $v243$;
