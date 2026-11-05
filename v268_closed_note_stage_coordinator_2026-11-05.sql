-- v268 (2026-11-05): رسالة «للعرض فقط» تعرض منسق المرحلة الفعلي بدل المالك.
-- ثانوي عام/صناعي ← محمد معله | إعدادي ← شيماء محمد فرج | ابتدائي ← بركات وأيمن.
-- يعدّل الدالة private.tp_closed_note فقط (لا بيانات ولا صلاحيات). الاسترجاع: rollback_v268_closed_note_2026-11-05.sql
create or replace function private.tp_closed_note(p_stage text)
 returns text
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
  with s as (select case when p_stage = 'ثانوي' then 'ثانوي عام' else p_stage end as st),
  c as (
    select sp.full_name, sp.phone
    from s, public.supervisors sp
    where sp.active and sp.phone is not null
      and sp.id in (
        case s.st
          when 'إعدادي' then '54161bac-29ed-4276-a0e0-a45b23ca4b8e'::uuid          -- شيماء محمد فرج
          when 'ثانوي عام' then '4d69363b-0b47-4d94-8c2d-d0e38d8c0f0a'::uuid       -- محمد معله الطاهر
          when 'ثانوي صناعي' then '4d69363b-0b47-4d94-8c2d-d0e38d8c0f0a'::uuid
        end,
        case when s.st = 'ابتدائي' then '78bf5551-962a-4543-a3cf-f54476797c8a'::uuid end,  -- بركات محمد محمود
        case when s.st = 'ابتدائي' then '32df5e67-3c36-4e97-9771-bff51e37dea0'::uuid end   -- ايمن وهيب رزق
      )
    order by sp.civil_id nulls first
  )
  select case when p_stage in ('إعدادي','ثانوي عام','ثانوي صناعي','ثانوي','ابتدائي') then
    'للعرض فقط — لأي تعديل يرجى التواصل مع '
    || case p_stage when 'ابتدائي' then 'منسقي ' else 'منسق ' end
    || case p_stage when 'إعدادي' then 'المرحلة الإعدادية' when 'ابتدائي' then 'المرحلة الابتدائية' when 'ثانوي صناعي' then 'الثانوي الصناعي' else 'الثانوي العام' end
    || ': ' || coalesce((select string_agg(full_name || ' — هاتف: ' || phone, ' | ') from c), '')
  end
$function$;
