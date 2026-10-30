-- استرجاع v227: التعريف السابق (v162) لـ private.accessible_school_ids() — يستدعي can_access_school لكل مدرسة.
create or replace function private.accessible_school_ids() returns uuid[]
language sql stable security definer set search_path to 'pg_catalog','private','public','pg_temp' as $function$
select coalesce(array_agg(s.id), '{}'::uuid[]) from public.schools s where private.can_access_school(s.id)
$function$;
