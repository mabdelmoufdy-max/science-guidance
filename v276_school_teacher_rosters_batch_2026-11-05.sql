-- v276: كشوف معلمي عدة مدارس في طلب واحد (بدل طلب لكل مدرسة بالتوازي → انتهاء المهلة)
create or replace function public.get_school_teacher_rosters(p_school_ids uuid[], p_term_id uuid)
returns jsonb language plpgsql stable security definer
set search_path to 'pg_catalog','private','public','pg_temp'
as $function$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'Unauthorized' using errcode='42501'; end if;
  if coalesce(cardinality(p_school_ids),0)=0 then return '[]'::jsonb; end if;
  if cardinality(p_school_ids)>200 then raise exception 'عدد المدارس أكبر من المسموح'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('school_id',x.id,'roster',private.school_teacher_roster(x.id,p_term_id)) order by x.ord),'[]'::jsonb)
    into v
  from (select distinct on (id) id, ord from unnest(p_school_ids) with ordinality u(id,ord) order by id, ord) x;
  return v;
end
$function$;
revoke all on function public.get_school_teacher_rosters(uuid[],uuid) from public, anon;
grant execute on function public.get_school_teacher_rosters(uuid[],uuid) to authenticated;
