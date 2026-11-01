-- v240 (2026-11-01): بوابة المعلمين للعرض فقط في الثانوي العام والثانوي الصناعي (كما الإعدادي منذ v180/v181)
-- التسجيل والتعديل من البوابة للابتدائي فقط. التعديل نصي على النص المخزن للدوال (كل نمط يجب أن يوجد مرة واحدة بالضبط).
-- النسخ الأصلية تُحفظ في private.v240_backup (لا تُحذف) — الاسترجاع: rollback_v240_portal_close_secondary_2026-11-01.sql

create table if not exists private.v240_backup (fn text primary key, def text not null, saved_at timestamptz not null default now());
revoke all on private.v240_backup from public, anon, authenticated;

create or replace function pg_temp.v240_rep(src text, old text, new text) returns text language plpgsql as $f$
declare cnt int := (length(src) - length(replace(src, old, ''))) / length(old);
begin
  if cnt <> 1 then raise exception 'v240: النمط موجود % مرة: %', cnt, left(old, 80); end if;
  return replace(src, old, new);
end $f$;

do $v240$
declare
  st constant text := $s$('إعدادي','ثانوي عام','ثانوي صناعي','ثانوي')$s$;
  f text; d text;
begin
  -- حفظ النسخ الأصلية (مرة واحدة فقط)
  foreach f in array array['public.teacher_portal_lookup(text,text)','public.teacher_portal_sup_school(text,text,uuid,text)',
    'public.teacher_portal_submit(text,text,text,jsonb)','public.teacher_portal_sup_submit(text,text,text,uuid,uuid,jsonb,text)',
    'public.teacher_portal_status()','private.tp_closed_note(text)'] loop
    insert into private.v240_backup(fn, def) values (f, pg_get_functiondef(f::regprocedure)) on conflict (fn) do nothing;
  end loop;

  -- 1) عرض المعلم
  d := pg_get_functiondef('public.teacher_portal_lookup(text,text)'::regprocedure);
  d := pg_temp.v240_rep(d, $o$if s.stage = 'إعدادي' then v_open := false; end if; -- v181$o$,
                           'if s.stage in ' || st || ' then v_open := false; end if; -- v181 + v240');
  execute d;

  -- 2) عرض مشرف المدرسة
  d := pg_get_functiondef('public.teacher_portal_sup_school(text,text,uuid,text)'::regprocedure);
  d := pg_temp.v240_rep(d, $o$if sch.stage = 'إعدادي' then v_open := false; end if; -- v181$o$,
                           'if sch.stage in ' || st || ' then v_open := false; end if; -- v181 + v240');
  execute d;

  -- 3) إرسال المعلم (تحديث/معلم جديد)
  d := pg_get_functiondef('public.teacher_portal_submit(text,text,text,jsonb)'::regprocedure);
  d := pg_temp.v240_rep(d, $o$-- v180: بوابة المعلمين مغلقة للمرحلة الإعدادية (التعديل والإضافة)$o$,
                           $n$-- v180 + v240: بوابة المعلمين مغلقة للإعدادي والثانوي العام والصناعي (التعديل والإضافة)$n$);
  d := pg_temp.v240_rep(d, $o$where tp.civil_id = private.tp_digits(p_civil) and sp.stage = 'إعدادي')$o$,
                           'where tp.civil_id = private.tp_digits(p_civil) and sp.stage in ' || st || ')');
  d := pg_temp.v240_rep(d, $o$where sp.stage = 'إعدادي' and sp.id::text = nullif(p_payload ->> 'school_id', '')) then$o$,
                           'where sp.stage in ' || st || $n$ and sp.id::text = nullif(p_payload ->> 'school_id', '')) then$n$);
  d := pg_temp.v240_rep(d, $o$'note', private.tp_closed_note('إعدادي'));$o$,
                           $n$'note', private.tp_closed_note(coalesce(
      (select sp.stage from public.teacher_records tp join public.schools sp on sp.id = tp.home_school_id
        where tp.civil_id = private.tp_digits(p_civil) and sp.stage in $n$ || st || $n$ limit 1),
      (select sp.stage from public.schools sp where sp.id::text = nullif(p_payload ->> 'school_id', '') limit 1))));$n$);
  execute d;

  -- 4) إرسال مشرف المدرسة
  d := pg_get_functiondef('public.teacher_portal_sup_submit(text,text,text,uuid,uuid,jsonb,text)'::regprocedure);
  d := pg_temp.v240_rep(d, $o$if sch.stage = 'إعدادي' then return$o$, 'if sch.stage in ' || st || ' then return');
  d := pg_temp.v240_rep(d, $o$end if; -- v180$o$, 'end if; -- v180 + v240');
  execute d;

  -- 5) حالة البوابة: المراحل المغلقة لشاشة «معلم جديد»
  d := pg_get_functiondef('public.teacher_portal_status()'::regprocedure);
  d := pg_temp.v240_rep(d, $o$'closed_stages', jsonb_build_object('prep', private.tp_closed_note('إعدادي')))$o$,
                           $n$'closed_stages', jsonb_build_object('prep', private.tp_closed_note('إعدادي'),
      'sec_general', private.tp_closed_note('ثانوي عام'), 'sec_industrial', private.tp_closed_note('ثانوي صناعي')))$n$);
  execute d;
end $v240$;

-- 6) نص «للعرض فقط» لكل مرحلة مغلقة (المنسق بالقاعدة نفسها: أول منسق نشط له هاتف بترتيب الرقم القومي)
create or replace function private.tp_closed_note(p_stage text)
 returns text
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
  with s as (select case when p_stage = 'ثانوي' then 'ثانوي عام' else p_stage end as st),
  c as (select sp.full_name, sp.phone from s, public.stage_coordinator_assignments a join public.supervisors sp on sp.id = a.supervisor_id
         where a.stage = s.st and a.active and sp.active and sp.phone is not null order by sp.civil_id nulls first limit 1)
  select case when p_stage in ('إعدادي','ثانوي عام','ثانوي صناعي','ثانوي') then
    'للعرض فقط — لأي تعديل يرجى التواصل مع منسق '
    || case p_stage when 'إعدادي' then 'المرحلة الإعدادية' when 'ثانوي صناعي' then 'الثانوي الصناعي' else 'الثانوي العام' end
    || ': ' || coalesce((select full_name from c), '') || ' — هاتف: ' || coalesce((select phone from c), '')
  end
$function$;
