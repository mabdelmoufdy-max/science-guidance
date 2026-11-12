-- v355 مركز التحكم — المرحلة 1 (قراءة فقط): دالتان لمدير النظام فقط
create or replace function public.admin_control_center()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v jsonb;
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  with
  sup as (select s.id, s.profile_id from public.supervisors s where s.profile_id is not null),
  sch_direct as (select sc.supervisor_id sid, sc.id school_id, sc.name, sc.stage, 'direct'::text how, null::text subj from public.schools sc where sc.supervisor_id is not null),
  sch_subj as (select ss.supervisor_id sid, sc.id school_id, sc.name, sc.stage, 'subject'::text how, ss.subject_name subj
               from public.supervisor_school_subjects ss join public.schools sc on sc.id = ss.school_id where ss.active),
  sch_all as (select * from sch_direct union all select * from sch_subj),
  acc as (
    select pr.id, pr.full_name, pr.civil_id, pr.phone, pr.is_active, pr.must_change_password, pr.created_at,
      au.last_sign_in_at,
      coalesce((select jsonb_agg(ur.role::text order by ur.role) from public.user_roles ur where ur.profile_id = pr.id and ur.is_active), '[]'::jsonb) roles,
      coalesce(up.last_seen_at > now() - interval '3 minutes', false) online,
      up.last_seen_at, up.active_role::text active_role,
      (select count(*) from public.user_access_log l where l.profile_id = pr.id and l.started_at > now() - interval '30 days') sessions30,
      (select l.device from public.user_access_log l where l.profile_id = pr.id order by l.started_at desc limit 1) last_device,
      (select count(*) from public.audit_log a where a.actor_profile_id = pr.id and a.created_at > now() - interval '30 days') actions30,
      (select a.created_at from public.audit_log a where a.actor_profile_id = pr.id order by a.created_at desc limit 1) last_action_at,
      (select s.id from sup s where s.profile_id = pr.id limit 1) sup_id,
      (select tr.id from public.teacher_records tr where tr.profile_id = pr.id limit 1) teacher_id
    from public.profiles pr
    left join auth.users au on au.id = pr.id
    left join public.user_presence up on up.profile_id = pr.id
  ),
  acc2 as (
    select a.*,
      coalesce((select jsonb_agg(distinct c.stage) from public.stage_coordinator_assignments c where c.supervisor_id = a.sup_id and c.active), '[]'::jsonb) coord_stages,
      coalesce((select jsonb_agg(jsonb_build_object('id', x.school_id, 'name', x.name, 'stage', x.stage, 'how', x.how, 'subjects', x.subjs) order by x.stage, x.name)
                from (select school_id, name, stage, min(how) how, jsonb_agg(distinct subj) filter (where subj is not null) subjs
                      from sch_all where sid = a.sup_id group by school_id, name, stage) x), '[]'::jsonb) sup_schools,
      (select jsonb_build_object('id', sc.id, 'name', sc.name, 'stage', sc.stage,
                'is_officer', exists(select 1 from public.school_data_officer o where o.teacher_id = a.teacher_id),
                'is_senior', coalesce(tr.is_senior_teacher, false))
         from public.teacher_records tr left join public.schools sc on sc.id = tr.home_school_id where tr.id = a.teacher_id) home_school
    from acc a
  ),
  users as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'name', full_name, 'civil_id', civil_id, 'phone', phone, 'active', is_active,
      'must_change_password', must_change_password, 'created_at', created_at, 'last_sign_in_at', last_sign_in_at,
      'roles', roles, 'online', online, 'last_seen_at', last_seen_at, 'active_role', active_role,
      'sessions30', sessions30, 'last_device', last_device, 'actions30', actions30, 'last_action_at', last_action_at,
      'coord_stages', coord_stages, 'schools', sup_schools, 'home_school', home_school
    ) order by online desc, full_name), '[]'::jsonb) j from acc2
  ),
  sig as (
    select jsonb_build_array(
      jsonb_build_object('code','sup_no_schools','level','bad','title','موجه له حساب بلا أي مدرسة في نطاقه',
        'items', coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.full_name)) from acc2 a
          where a.is_active and a.roles ? 'supervisor' and jsonb_array_length(a.sup_schools)=0 and jsonb_array_length(a.coord_stages)=0),'[]'::jsonb)),
      jsonb_build_object('code','school_no_supervisor','level','bad','title','مدارس بلا موجه',
        'items', coalesce((select jsonb_agg(jsonb_build_object('id',sc.id,'name',sc.name,'stage',sc.stage) order by sc.stage, sc.name) from public.schools sc
          where sc.supervisor_id is null and not exists(select 1 from public.supervisor_school_subjects ss where ss.school_id=sc.id and ss.active)),'[]'::jsonb)),
      jsonb_build_object('code','school_sup_no_account','level','bad','title','مدارس موجهها بلا حساب دخول نشط',
        'items', coalesce((select jsonb_agg(jsonb_build_object('id',x.school_id,'name',x.name,'stage',x.stage) order by x.stage, x.name)
          from (select distinct sa.school_id, sa.name, sa.stage from sch_all sa join public.supervisors s on s.id = sa.sid
                left join public.profiles p on p.id = s.profile_id
                where s.active and (s.profile_id is null or not coalesce(p.is_active,false)
                  or not exists(select 1 from public.user_roles ur where ur.profile_id=s.profile_id and ur.is_active and ur.role in ('supervisor','stage_coordinator')))) x),'[]'::jsonb)),
      jsonb_build_object('code','temp_password','level','warn','title','حسابات بكلمة مرور مؤقتة لم تتغير منذ أكثر من 14 يومًا',
        'items', coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.full_name)) from acc2 a
          where a.is_active and a.must_change_password and a.created_at < now() - interval '14 days'),'[]'::jsonb)),
      jsonb_build_object('code','never_signed_in','level','warn','title','حسابات نشطة لم تسجّل الدخول خلال 30 يومًا',
        'items', coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.full_name)) from acc2 a
          where a.is_active and jsonb_array_length(a.roles)>0 and (a.last_sign_in_at is null or a.last_sign_in_at < now() - interval '30 days')),'[]'::jsonb)),
      jsonb_build_object('code','login_failures','level','warn','title','محاولات دخول مرفوضة متكررة (5 أو أكثر خلال 24 ساعة)',
        'items', coalesce((select jsonb_agg(jsonb_build_object('name',f.identifier,'count',f.c)) from
          (select identifier, count(*) c from public.login_failures where created_at > now() - interval '24 hours' group by identifier having count(*) >= 5) f),'[]'::jsonb)),
      jsonb_build_object('code','inactive_with_roles','level','info','title','حسابات معطلة ما زالت لها أدوار نشطة',
        'items', coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.full_name)) from acc2 a
          where not a.is_active and jsonb_array_length(a.roles)>0),'[]'::jsonb))
    ) j
  )
  select jsonb_build_object(
    'generated_at', now(),
    'stats', jsonb_build_object(
      'accounts', (select count(*) from public.profiles where is_active),
      'online', (select count(*) from public.user_presence where last_seen_at > now() - interval '3 minutes'),
      'sessions_today', (select count(*) from public.user_access_log where started_at >= date_trunc('day', now())),
      'failures_24h', (select count(*) from public.login_failures where created_at > now() - interval '24 hours'),
      'actions_7d', (select count(*) from public.audit_log where created_at > now() - interval '7 days'),
      'schools', (select count(*) from public.schools),
      'teachers', (select count(*) from public.teacher_records where active),
      'roles', coalesce((select jsonb_object_agg(role, c) from (select role::text role, count(*) c from public.user_roles where is_active group by role) r), '{}'::jsonb),
      'actions_by_role_7d', coalesce((select jsonb_object_agg(coalesce(r,'—'), c) from (select actor_role::text r, count(*) c from public.audit_log where created_at > now() - interval '7 days' group by actor_role) r), '{}'::jsonb)
    ),
    'flags', (select jsonb_build_object('editing_open', editing_open, 'timetable_open', timetable_open, 'updated_at', updated_at) from public.teacher_portal_settings where id = 1),
    'users', (select j from users),
    'signals', (select j from sig)
  ) into v;
  return v;
end
$fn$;

create or replace function public.admin_audit_search(p_from timestamptz, p_to timestamptz, p_actor uuid default null, p_q text default null, p_limit int default 300)
returns table(id bigint, created_at timestamptz, actor_profile_id uuid, actor_name text, actor_role text, action text, entity_type text, entity_id text, old_data jsonb, new_data jsonb)
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
#variable_conflict use_column
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return query
  select a.id, a.created_at, a.actor_profile_id, pr.full_name, a.actor_role::text, a.action, a.entity_type, a.entity_id, a.old_data, a.new_data
  from public.audit_log a left join public.profiles pr on pr.id = a.actor_profile_id
  where a.created_at >= p_from and a.created_at < p_to
    and (p_actor is null or a.actor_profile_id = p_actor)
    and (nullif(p_q,'') is null or a.action ilike '%'||p_q||'%' or a.entity_type ilike '%'||p_q||'%' or a.entity_id = p_q)
  order by a.created_at desc
  limit least(greatest(coalesce(p_limit,300),1),1000);
end
$fn$;

revoke all on function public.admin_control_center() from public, anon;
revoke all on function public.admin_audit_search(timestamptz,timestamptz,uuid,text,int) from public, anon;
grant execute on function public.admin_control_center() to authenticated;
grant execute on function public.admin_audit_search(timestamptz,timestamptz,uuid,text,int) to authenticated;
