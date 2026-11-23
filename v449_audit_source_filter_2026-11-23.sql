-- v449 — Classify and filter the control-center audit log.
-- مطبّق 2026-11-23 (migration v449_audit_source_filter_2026_11_23). النص كما حُفظ في supabase_migrations.
-- المصدر: program = actor_profile_id غير فارغ؛ portal = بلا فاعل و(portal_actor_name أو teacher_portal_* أو paid_teacher_*)؛ system = الباقي.
do $migration$
begin
create function private.v449_audit_source(actor_profile_id uuid, action text, new_data jsonb)
returns text
language sql
immutable
set search_path = pg_catalog, pg_temp
as $source$
  select case
    when $1 is not null then 'program'
    when $3 ? 'portal_actor_name'
      or starts_with($2, 'teacher_portal_')
      or starts_with($2, 'paid_teacher_') then 'portal'
    else 'system'
  end;
$source$;

CREATE FUNCTION public.admin_audit_search3(p_from timestamp with time zone, p_to timestamp with time zone, p_actor uuid DEFAULT NULL::uuid, p_action text DEFAULT NULL::text, p_q text DEFAULT NULL::text, p_target uuid DEFAULT NULL::uuid, p_before bigint DEFAULT NULL::bigint, p_limit integer DEFAULT 200, p_source text DEFAULT NULL)
 RETURNS TABLE(id bigint, created_at timestamp with time zone, actor_profile_id uuid, actor_name text, actor_role text, action text, entity_type text, entity_id text, target_name text, old_data jsonb, new_data jsonb, source text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
#variable_conflict use_column
declare v_q text := nullif(btrim(coalesce(p_q,'')), ''); v_t text := p_target::text;
begin
  perform private.v356_require_admin();
  if p_source is not null and p_source not in ('program', 'portal', 'system') then
    raise exception 'invalid audit source' using errcode = '22023';
  end if;
  return query
  select a.id, a.created_at, a.actor_profile_id,
         case when a.actor_profile_id is null then nullif(a.new_data->>'portal_actor_name', '') || ' (من البوابة)' else pa.full_name end,
         a.actor_role::text, a.action, a.entity_type, a.entity_id,
         coalesce(pt.full_name, tr.full_name, sc.name,
                  (select p2.full_name from public.profiles p2 where p2.id::text = a.new_data->>'profile_id'),
                  a.new_data->>'teacher_name', a.new_data->>'school_name', a.new_data->>'to_name'),
         a.old_data, a.new_data, private.v449_audit_source(a.actor_profile_id, a.action, a.new_data)
  from public.audit_log a
  left join public.profiles pa on pa.id = a.actor_profile_id
  left join public.profiles pt on pt.id::text = a.entity_id
  left join public.teacher_records tr on tr.id::text = a.entity_id
  left join public.schools sc on sc.id::text = a.entity_id
  where a.created_at >= p_from and a.created_at < p_to
    and (p_source is null or private.v449_audit_source(a.actor_profile_id, a.action, a.new_data) = p_source)
    and (p_actor is null or a.actor_profile_id = p_actor)
    and (nullif(p_action,'') is null or a.action = p_action)
    and (p_before is null or a.id < p_before)
    and (v_t is null or a.entity_id = v_t or a.new_data->>'profile_id' = v_t or a.old_data->>'profile_id' = v_t)
    and (v_q is null or a.entity_id = v_q or a.action ilike '%'||v_q||'%'
         or coalesce(pt.full_name, tr.full_name, sc.name, '') ilike '%'||v_q||'%'
         or a.new_data::text ilike '%'||v_q||'%' or a.old_data::text ilike '%'||v_q||'%')
  order by a.id desc
  limit least(greatest(coalesce(p_limit,200),1),500);
end $function$
;

CREATE FUNCTION public.admin_audit_actions2(p_from timestamp with time zone, p_to timestamp with time zone, p_source text DEFAULT NULL)
 RETURNS TABLE(action text, n bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
#variable_conflict use_column
begin
  perform private.v356_require_admin();
  if p_source is not null and p_source not in ('program', 'portal', 'system') then
    raise exception 'invalid audit source' using errcode = '22023';
  end if;
  return query select a.action, count(*) from public.audit_log a
   where a.created_at >= p_from and a.created_at < p_to
    and (p_source is null or private.v449_audit_source(a.actor_profile_id, a.action, a.new_data) = p_source)
   group by a.action order by count(*) desc;
end $function$
;

revoke all on function public.admin_audit_search3(timestamptz,timestamptz,uuid,text,text,uuid,bigint,integer,text) from public, anon, authenticated, service_role;
revoke all on function public.admin_audit_actions2(timestamptz,timestamptz,text) from public, anon, authenticated, service_role;
revoke all on function private.v449_audit_source(uuid,text,jsonb) from public, anon, authenticated, service_role;
grant execute on function public.admin_audit_search3(timestamptz,timestamptz,uuid,text,text,uuid,bigint,integer,text) to authenticated;
grant execute on function public.admin_audit_actions2(timestamptz,timestamptz,text) to authenticated;

end;
$migration$;
