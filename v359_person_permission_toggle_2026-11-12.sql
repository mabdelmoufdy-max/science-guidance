-- v359: التحكم في إجراءات شخص بعينه من نافذة «ما الذي يراه ويفعله؟» — استثناء دائم حتى يُلغى (expires_at فارغ) أو بمدة
alter table public.permission_grants alter column expires_at drop not null;

create or replace function private.cap_allowed(p_cap text) returns boolean
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_role public.app_role; v_g boolean;
begin
  if auth.uid() is null then return true; end if;
  v_role := private.current_app_role();
  if v_role is null or v_role = 'admin' then return true; end if;
  select g.allowed into v_g from public.permission_grants g
   where g.profile_id = auth.uid() and g.capability = p_cap and g.revoked_at is null
     and now() >= g.starts_at and (g.expires_at is null or now() < g.expires_at)
   order by g.created_at desc limit 1;
  if found then return v_g; end if;
  return coalesce((select allowed from public.permission_rules where capability = p_cap and role = v_role), true);
end $fn$;

-- p_days فارغ = دائم حتى يُلغى؛ وإلا 1–90 يومًا. يُلغي أي استثناء سارٍ للشخص على الإجراء نفسه قبل الإضافة
create or replace function public.admin_grant_add(p_profile uuid, p_cap text, p_allowed boolean, p_days int, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_id uuid; v_exp timestamptz;
begin
  if p_days is not null and (p_days < 1 or p_days > 90) then raise exception 'المدة من يوم إلى 90 يومًا، أو «دائم»'; end if;
  if not exists(select 1 from public.profiles where id = p_profile) then raise exception 'الحساب غير موجود'; end if;
  if not exists(select 1 from public.permission_capabilities where code = p_cap) then raise exception 'إجراء غير معروف'; end if;
  if exists(select 1 from public.user_roles where profile_id = p_profile and role = 'admin' and is_active) then raise exception 'مدير النظام لا يحتاج استثناءً'; end if;
  update public.permission_grants set revoked_at = now(), revoked_by = v_actor
   where profile_id = p_profile and capability = p_cap and revoked_at is null and (expires_at is null or expires_at > now());
  v_exp := case when p_days is null then null else now() + make_interval(days => p_days) end;
  insert into public.permission_grants(profile_id, capability, allowed, expires_at, reason, created_by)
  values (p_profile, p_cap, p_allowed, v_exp, nullif(p_reason,''), v_actor) returning id into v_id;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_grant_add', 'permission_grant', v_id::text, null,
          jsonb_build_object('profile_id', p_profile, 'cap', p_cap, 'allowed', p_allowed, 'expires_at', v_exp, 'permanent', p_days is null, 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true, 'id', v_id, 'expires_at', v_exp);
end $fn$;

create or replace function public.admin_grants_list()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
begin
  perform private.v356_require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', g.id, 'profile_id', g.profile_id, 'name', p.full_name, 'cap', g.capability, 'label', c.label, 'allowed', g.allowed,
      'starts_at', g.starts_at, 'expires_at', g.expires_at, 'reason', g.reason, 'created_at', g.created_at, 'created_by_name', cb.full_name,
      'revoked_at', g.revoked_at,
      'status', case when g.revoked_at is not null then 'revoked' when g.expires_at is not null and now() >= g.expires_at then 'expired' else 'active' end)
      order by (g.revoked_at is null and (g.expires_at is null or now() < g.expires_at)) desc, g.created_at desc)
    from public.permission_grants g
    join public.profiles p on p.id = g.profile_id
    join public.permission_capabilities c on c.code = g.capability
    left join public.profiles cb on cb.id = g.created_by
    where g.created_at > now() - interval '120 days' or (g.revoked_at is null and g.expires_at is null)), '[]'::jsonb);
end $fn$;

create or replace function public.admin_view_as(p_profile uuid, p_role text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  v_actor uuid := private.v356_require_admin();
  v_claims text := current_setting('request.jwt.claims', true);
  v_headers text := current_setting('request.headers', true);
  v_eff text; v_sch uuid[]; v_tch uuid[]; v_caps jsonb; v_res jsonb;
begin
  if not exists(select 1 from public.user_roles where profile_id = p_profile and role::text = p_role and is_active) then
    raise exception 'هذا الدور غير نشط لهذا الحساب';
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_profile, 'role', 'authenticated')::text, true);
    perform set_config('request.headers', json_build_object('x-app-role', p_role)::text, true);
    v_eff := private.current_app_role()::text;
    v_sch := coalesce(private.accessible_school_ids(), '{}');
    v_tch := coalesce(private.v336_visible_teacher_ids(), '{}');
    select coalesce(jsonb_agg(jsonb_build_object('code', c.code, 'label', c.label, 'allowed', private.cap_allowed(c.code),
             'role_allowed', coalesce((select r.allowed from public.permission_rules r where r.capability = c.code and r.role::text = p_role), true),
             'grant', (select jsonb_build_object('id', g.id, 'allowed', g.allowed, 'expires_at', g.expires_at)
                         from public.permission_grants g where g.profile_id = p_profile and g.capability = c.code and g.revoked_at is null
                          and now() >= g.starts_at and (g.expires_at is null or now() < g.expires_at) order by g.created_at desc limit 1),
             'by_grant', exists(select 1 from public.permission_grants g where g.profile_id = p_profile and g.capability = c.code and g.revoked_at is null
                          and now() >= g.starts_at and (g.expires_at is null or now() < g.expires_at))) order by c.sort), '[]'::jsonb)
      into v_caps from public.permission_capabilities c;
  exception when others then
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    perform set_config('request.headers', coalesce(v_headers, ''), true);
    raise;
  end;
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.headers', coalesce(v_headers, ''), true);
  select jsonb_build_object(
    'role', p_role, 'effective_role', v_eff,
    'schools_count', coalesce(array_length(v_sch, 1), 0),
    'teachers_count', coalesce(array_length(v_tch, 1), 0),
    'by_stage', coalesce((select jsonb_object_agg(stage, n) from (select sc.stage, count(*) n from public.schools sc where sc.id = any(v_sch) group by sc.stage) s), '{}'::jsonb),
    'schools', coalesce((select jsonb_agg(jsonb_build_object('name', sc.name, 'stage', sc.stage) order by sc.stage, sc.name) from (select * from public.schools where id = any(v_sch) order by stage, name limit 300) sc), '[]'::jsonb),
    'capabilities', v_caps)
  into v_res;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_view_as', 'profile', p_profile::text, null, jsonb_build_object('role', p_role));
  return v_res;
end $fn$;
