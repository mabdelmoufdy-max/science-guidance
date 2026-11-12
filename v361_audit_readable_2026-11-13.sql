-- v361 مركز التحكم — الاقتراح ٢: سجل الحساب وتدقيق مفهوم (قراءة فقط، مدير النظام فقط)
-- 1) بحث التدقيق الموسّع: نوع الإجراء، بحث في المحتوى، ما فُعل بحساب/سجل بعينه، اسم السجل المتأثر، وصفحات (p_before)
create or replace function public.admin_audit_search2(
  p_from timestamptz, p_to timestamptz, p_actor uuid default null, p_action text default null,
  p_q text default null, p_target uuid default null, p_before bigint default null, p_limit int default 200)
returns table(id bigint, created_at timestamptz, actor_profile_id uuid, actor_name text, actor_role text, action text,
              entity_type text, entity_id text, target_name text, old_data jsonb, new_data jsonb)
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
#variable_conflict use_column
declare v_q text := nullif(btrim(coalesce(p_q,'')), ''); v_t text := p_target::text;
begin
  perform private.v356_require_admin();
  return query
  select a.id, a.created_at, a.actor_profile_id, pa.full_name, a.actor_role::text, a.action, a.entity_type, a.entity_id,
         coalesce(pt.full_name, tr.full_name, sc.name,
                  (select p2.full_name from public.profiles p2 where p2.id::text = a.new_data->>'profile_id'),
                  a.new_data->>'teacher_name', a.new_data->>'school_name', a.new_data->>'to_name'),
         a.old_data, a.new_data
  from public.audit_log a
  left join public.profiles pa on pa.id = a.actor_profile_id
  left join public.profiles pt on pt.id::text = a.entity_id
  left join public.teacher_records tr on tr.id::text = a.entity_id
  left join public.schools sc on sc.id::text = a.entity_id
  where a.created_at >= p_from and a.created_at < p_to
    and (p_actor is null or a.actor_profile_id = p_actor)
    and (nullif(p_action,'') is null or a.action = p_action)
    and (p_before is null or a.id < p_before)
    and (v_t is null or a.entity_id = v_t or a.new_data->>'profile_id' = v_t or a.old_data->>'profile_id' = v_t)
    and (v_q is null or a.entity_id = v_q or a.action ilike '%'||v_q||'%'
         or coalesce(pt.full_name, tr.full_name, sc.name, '') ilike '%'||v_q||'%'
         or a.new_data::text ilike '%'||v_q||'%' or a.old_data::text ilike '%'||v_q||'%')
  order by a.id desc
  limit least(greatest(coalesce(p_limit,200),1),500);
end $fn$;

-- 2) أنواع الإجراءات في الفترة (لقائمة الاختيار)
create or replace function public.admin_audit_actions(p_from timestamptz, p_to timestamptz)
returns table(action text, n bigint)
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
#variable_conflict use_column
begin
  perform private.v356_require_admin();
  return query select a.action, count(*) from public.audit_log a
   where a.created_at >= p_from and a.created_at < p_to group by a.action order by count(*) desc;
end $fn$;

revoke all on function public.admin_audit_search2(timestamptz,timestamptz,uuid,text,text,uuid,bigint,int) from public, anon;
revoke all on function public.admin_audit_actions(timestamptz,timestamptz) from public, anon;
grant execute on function public.admin_audit_search2(timestamptz,timestamptz,uuid,text,text,uuid,bigint,int) to authenticated;
grant execute on function public.admin_audit_actions(timestamptz,timestamptz) to authenticated;

-- 3) «ما الذي يراه» يُسجَّل مرة كل 10 دقائق لكل (شخص، دور) بدل كل فتح — استبدال نصي مرة واحدة
do $m$
declare d text; n text;
  k text := $s$  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_view_as', 'profile', p_profile::text, null, jsonb_build_object('role', p_role));$s$;
begin
  select pg_get_functiondef('public.admin_view_as(uuid,text)'::regprocedure) into d;
  if (length(d) - length(replace(d, k, ''))) / length(k) <> 1 then raise exception 'v361: نص admin_view_as غير مطابق'; end if;
  n := replace(d, k, $s$  if not exists(select 1 from public.audit_log l where l.action = 'cc_view_as' and l.actor_profile_id = v_actor
                   and l.entity_id = p_profile::text and l.new_data->>'role' = p_role and l.created_at > now() - interval '10 minutes') then
$s$ || k || $s$
  end if;$s$);
  execute n;
end $m$;
