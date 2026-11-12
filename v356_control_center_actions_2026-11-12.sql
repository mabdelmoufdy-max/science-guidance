-- v356 مركز التحكم — المرحلة 2: أفعال الحسابات والنطاق والمفاتيح (مدير النظام فقط، كل فعل في audit_log)

create or replace function private.v356_require_admin() returns uuid
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
begin
  if auth.uid() is null or private.current_app_role() is distinct from 'admin'::public.app_role then
    raise exception 'غير مصرح: هذه العملية لمدير النظام فقط' using errcode = '42501';
  end if;
  return auth.uid();
end $fn$;
revoke all on function private.v356_require_admin() from public, anon;
grant execute on function private.v356_require_admin() to authenticated;

-- أفعال الحساب: disable | enable | end_sessions | force_password(true/false) | role_on/role_off(role) | coord_stage_on/coord_stage_off(stage)
create or replace function public.admin_account_action(p_profile uuid, p_action text, p_value text default null, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  v_actor uuid := private.v356_require_admin();
  v_p public.profiles%rowtype;
  v_sup uuid; v_tr uuid; v_role public.app_role; v_old jsonb; v_new jsonb; v_n int := 0;
  v_allowed text[] := array['stage_coordinator','supervisor','first_supervisor','teacher','school_manager'];
  v_stages text[] := array['ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي'];
begin
  select * into v_p from public.profiles where id = p_profile;
  if not found then raise exception 'الحساب غير موجود'; end if;
  select id into v_sup from public.supervisors where profile_id = p_profile limit 1;
  select id into v_tr from public.teacher_records where profile_id = p_profile limit 1;
  v_old := jsonb_build_object('is_active', v_p.is_active, 'must_change_password', v_p.must_change_password,
    'roles', (select coalesce(jsonb_agg(role::text order by role), '[]'::jsonb) from public.user_roles where profile_id = p_profile and is_active),
    'coord_stages', (select coalesce(jsonb_agg(stage order by stage), '[]'::jsonb) from public.stage_coordinator_assignments where supervisor_id = v_sup and active));

  if p_action in ('disable','end_sessions','role_off','coord_stage_off') and p_profile = v_actor then
    raise exception 'لا يمكنك تنفيذ هذا الإجراء على حسابك أنت';
  end if;
  if p_action = 'disable' and exists(select 1 from public.user_roles where profile_id = p_profile and role = 'admin' and is_active) then
    raise exception 'لا يمكن تعطيل حساب مدير نظام';
  end if;

  if p_action = 'disable' then
    update public.profiles set is_active = false where id = p_profile;
    update auth.users set banned_until = 'infinity' where id = p_profile;
    update auth.sessions set not_after = now() where user_id = p_profile and (not_after is null or not_after > now());
    get diagnostics v_n = row_count;
    update auth.refresh_tokens set revoked = true where user_id = p_profile::text and not coalesce(revoked,false);
  elsif p_action = 'enable' then
    update public.profiles set is_active = true where id = p_profile;
    update auth.users set banned_until = null where id = p_profile;
  elsif p_action = 'end_sessions' then
    update auth.sessions set not_after = now() where user_id = p_profile and (not_after is null or not_after > now());
    get diagnostics v_n = row_count;
    update auth.refresh_tokens set revoked = true where user_id = p_profile::text and not coalesce(revoked,false);
  elsif p_action = 'force_password' then
    update public.profiles set must_change_password = coalesce(p_value,'true')::boolean where id = p_profile;
  elsif p_action in ('role_on','role_off') then
    if p_value is null or not (p_value = any(v_allowed)) then
      raise exception 'هذا الدور لا يُغيَّر من هنا (مدير النظام ثابت، وحساب المدرسة يتبع مشرف المادة/مسؤول البيانات تلقائيًا)';
    end if;
    v_role := p_value::public.app_role;
    if p_action = 'role_on' then
      if p_value in ('supervisor','stage_coordinator','first_supervisor') and v_sup is null then
        raise exception 'لا يوجد سجل موجه مرتبط بهذا الحساب';
      end if;
      if p_value = 'teacher' and v_tr is null then raise exception 'لا يوجد سجل معلم مرتبط بهذا الحساب'; end if;
      if p_value = 'stage_coordinator' and not exists(select 1 from public.stage_coordinator_assignments where supervisor_id = v_sup and active) then
        raise exception 'حدّد مرحلة المنسق أولًا (تفعيل مرحلة يفعّل الدور تلقائيًا)';
      end if;
      insert into public.user_roles(profile_id, role, is_active, assigned_by, assigned_at)
      values (p_profile, v_role, true, v_actor, now())
      on conflict (profile_id, role) do update set is_active = true, assigned_by = v_actor, assigned_at = now();
    else
      update public.user_roles set is_active = false where profile_id = p_profile and role = v_role;
    end if;
  elsif p_action in ('coord_stage_on','coord_stage_off') then
    if v_sup is null then raise exception 'لا يوجد سجل موجه مرتبط بهذا الحساب'; end if;
    if p_value is null or not (p_value = any(v_stages)) then raise exception 'مرحلة غير صحيحة'; end if;
    if p_action = 'coord_stage_on' then
      insert into public.stage_coordinator_assignments(supervisor_id, stage, active, assigned_by, assigned_at)
      values (v_sup, p_value, true, v_actor, now())
      on conflict (supervisor_id, stage) do update set active = true, assigned_by = v_actor, assigned_at = now();
      insert into public.user_roles(profile_id, role, is_active, assigned_by, assigned_at)
      values (p_profile, 'stage_coordinator', true, v_actor, now())
      on conflict (profile_id, role) do update set is_active = true;
    else
      update public.stage_coordinator_assignments set active = false where supervisor_id = v_sup and stage = p_value;
      if not exists(select 1 from public.stage_coordinator_assignments where supervisor_id = v_sup and active) then
        update public.user_roles set is_active = false where profile_id = p_profile and role = 'stage_coordinator';
      end if;
    end if;
  else
    raise exception 'إجراء غير معروف: %', p_action;
  end if;

  select jsonb_build_object('is_active', is_active, 'must_change_password', must_change_password,
    'roles', (select coalesce(jsonb_agg(role::text order by role), '[]'::jsonb) from public.user_roles where profile_id = p_profile and is_active),
    'coord_stages', (select coalesce(jsonb_agg(stage order by stage), '[]'::jsonb) from public.stage_coordinator_assignments where supervisor_id = v_sup and active))
    into v_new from public.profiles where id = p_profile;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_'||p_action, 'profile', p_profile::text, v_old,
          v_new || jsonb_build_object('value', p_value, 'reason', nullif(p_reason,''), 'sessions_ended', v_n));
  return jsonb_build_object('ok', true, 'before', v_old, 'after', v_new, 'sessions_ended', v_n);
end $fn$;

-- نقل مدارس بين موجهين (الإعدادي والابتدائي؛ الثانوي بالمادة من شاشة إدخال المدارس). p_apply=false = معاينة الأثر فقط
create or replace function public.admin_move_schools(p_school_ids uuid[], p_to_supervisor uuid, p_apply boolean default false, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare
  v_actor uuid := private.v356_require_admin();
  v_to public.supervisors%rowtype; v_rows jsonb; v_bad int; v_n int := 0;
begin
  if p_school_ids is null or cardinality(p_school_ids) = 0 then raise exception 'اختر مدرسة واحدة على الأقل'; end if;
  if cardinality(p_school_ids) > 100 then raise exception 'الحد 100 مدرسة في المرة'; end if;
  select * into v_to from public.supervisors where id = p_to_supervisor;
  if not found or not v_to.active then raise exception 'الموجه الجديد غير موجود أو غير نشط'; end if;
  select count(*) into v_bad from public.schools where id = any(p_school_ids) and stage like 'ثانوي%';
  if v_bad > 0 then raise exception 'مدارس الثانوي تُسند بالمادة من شاشة إدخال بيانات المدارس، لا من هنا'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', sc.id, 'name', sc.name, 'stage', sc.stage,
      'from_id', sc.supervisor_id, 'from_name', fs.full_name,
      'same', sc.supervisor_id is not distinct from p_to_supervisor,
      'teachers', (select count(*) from public.teacher_records tr where tr.home_school_id = sc.id and tr.active),
      'pending', (select count(*) from public.school_submissions s where s.school_id = sc.id and s.status::text like 'pending%'),
      'stage_ok', exists(select 1 from public.supervisor_stage_assignments a where a.supervisor_id = p_to_supervisor and a.stage = sc.stage and a.active)
    ) order by sc.name), '[]'::jsonb)
  into v_rows
  from public.schools sc left join public.supervisors fs on fs.id = sc.supervisor_id
  where sc.id = any(p_school_ids);

  if p_apply then
    update public.schools set supervisor_id = p_to_supervisor
    where id = any(p_school_ids) and supervisor_id is distinct from p_to_supervisor;
    get diagnostics v_n = row_count;
    insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
    values (v_actor, 'admin', 'cc_move_schools', 'schools', p_to_supervisor::text,
      jsonb_build_object('schools', v_rows),
      jsonb_build_object('to_supervisor', p_to_supervisor, 'to_name', v_to.full_name, 'moved', v_n, 'reason', nullif(p_reason,'')));
  end if;
  return jsonb_build_object('to_name', v_to.full_name, 'applied', p_apply, 'moved', v_n, 'schools', v_rows);
end $fn$;

-- مفاتيح البوابة: editing_open | timetable_open
create or replace function public.admin_set_flag(p_flag text, p_value boolean, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); v_old boolean;
begin
  if p_flag = 'editing_open' then
    select editing_open into v_old from public.teacher_portal_settings where id = 1;
    update public.teacher_portal_settings set editing_open = p_value, updated_at = now() where id = 1;
  elsif p_flag = 'timetable_open' then
    select timetable_open into v_old from public.teacher_portal_settings where id = 1;
    update public.teacher_portal_settings set timetable_open = p_value, updated_at = now() where id = 1;
  else
    raise exception 'مفتاح غير معروف';
  end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_flag', 'teacher_portal_settings', p_flag, jsonb_build_object(p_flag, v_old), jsonb_build_object(p_flag, p_value, 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true, 'flag', p_flag, 'before', v_old, 'after', p_value);
end $fn$;

revoke all on function public.admin_account_action(uuid,text,text,text) from public, anon;
revoke all on function public.admin_move_schools(uuid[],uuid,boolean,text) from public, anon;
revoke all on function public.admin_set_flag(text,boolean,text) from public, anon;
grant execute on function public.admin_account_action(uuid,text,text,text) to authenticated;
grant execute on function public.admin_move_schools(uuid[],uuid,boolean,text) to authenticated;
grant execute on function public.admin_set_flag(text,boolean,text) to authenticated;
