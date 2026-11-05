-- استرجاع v268: إعادة نص private.tp_closed_note كما في v240
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
