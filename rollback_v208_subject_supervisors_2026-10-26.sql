-- استرجاع v208: يعيد الدوال الثلاث إلى تعريفها السابق (الموجه = schools.supervisor_id فقط) ثم يحذف السياسات والدالة المساعدة (شغّله من SQL Editor)
create or replace function private.can_access_school(target_school uuid) returns boolean language plpgsql stable security definer set search_path to 'pg_catalog','public','pg_temp' as $function$
declare r public.app_role;
begin
  if auth.uid() is null then return false; end if;
  r := private.current_app_role();
  if r in ('admin','first_supervisor') then return true; end if;
  if r='stage_coordinator' then
    return exists(select 1 from public.schools s where s.id=target_school and private.can_access_stage(s.stage));
  end if;
  if r='supervisor' then
    return exists(select 1 from public.schools s where s.id=target_school and s.supervisor_id=private.current_supervisor_id());
  end if;
  if r='school_manager' then
    return exists(select 1 from public.schools s where s.id=target_school and s.manager_profile_id=auth.uid());
  end if;
  if r in ('senior_teacher','teacher') then
    return exists(
      select 1 from public.teacher_school_assignments tsa
      join public.teacher_records tr on tr.id=tsa.teacher_id
      where tr.profile_id=auth.uid() and tsa.school_id=target_school and tsa.active
    ) or private.current_home_school_id()=target_school;
  end if;
  return false;
end$function$;

create or replace function private.can_access_teacher(target_teacher uuid) returns boolean language plpgsql stable security definer set search_path to 'pg_catalog','public','pg_temp' as $function$
declare r public.app_role; v_home_school uuid; v_supervisor uuid;
begin
  if auth.uid() is null then return false; end if;
  if exists(select 1 from public.teacher_records tr where tr.id=target_teacher and tr.profile_id=auth.uid()) then return true; end if;
  r := private.current_app_role();
  if r is null then return false; end if;
  if r in ('admin','first_supervisor') then return true; end if;
  if r='teacher' then return false; end if;
  if r='stage_coordinator' then
    return exists(select 1 from public.teacher_records tr join public.schools s on s.id=tr.home_school_id where tr.id=target_teacher and private.can_access_stage(s.stage))
    or exists(select 1 from public.delegations d join public.schools s on s.id=d.to_school_id where d.teacher_id=target_teacher and d.active and d.start_date<=current_date and (d.end_date is null or d.end_date>=current_date) and private.can_access_stage(s.stage));
  end if;
  if r='supervisor' then
    v_supervisor := private.current_supervisor_id();
    return exists(select 1 from public.teacher_records tr join public.schools s on s.id=tr.home_school_id where tr.id=target_teacher and s.supervisor_id=v_supervisor)
    or exists(select 1 from public.delegations d join public.schools s on s.id=d.to_school_id where d.teacher_id=target_teacher and d.active and d.start_date<=current_date and (d.end_date is null or d.end_date>=current_date) and s.supervisor_id=v_supervisor);
  end if;
  if r='school_manager' then
    return exists(select 1 from public.teacher_records tr join public.schools s on s.id=tr.home_school_id where tr.id=target_teacher and s.manager_profile_id=auth.uid())
    or exists(select 1 from public.delegations d join public.schools s on s.id=d.to_school_id where d.teacher_id=target_teacher and d.active and d.start_date<=current_date and (d.end_date is null or d.end_date>=current_date) and s.manager_profile_id=auth.uid());
  end if;
  if r in ('senior_teacher','teacher') then
    v_home_school := private.current_home_school_id();
    if v_home_school is null then return false; end if;
    return exists(select 1 from public.teacher_records tr where tr.id=target_teacher and tr.home_school_id=v_home_school)
    or exists(select 1 from public.delegations d where d.teacher_id=target_teacher and d.to_school_id=v_home_school and d.active and d.start_date<=current_date and (d.end_date is null or d.end_date>=current_date));
  end if;
  return false;
end
$function$;

create or replace function private.can_access_profile(target_profile uuid) returns boolean language plpgsql stable security definer set search_path to 'pg_catalog','public','pg_temp' as $function$
declare r public.app_role; sup uuid; hs uuid;
begin
  if auth.uid() is null then return false; end if;
  if target_profile=auth.uid() then return true; end if;
  r := private.current_app_role();
  if r in ('admin','first_supervisor') then return true; end if;
  if r='stage_coordinator' then
    return exists(select 1 from public.teacher_records tr join public.schools s on s.id=tr.home_school_id where tr.profile_id=target_profile and private.can_access_stage(s.stage))
    or exists(select 1 from public.supervisors sp join public.supervisor_stage_assignments ssa on ssa.supervisor_id=sp.id and ssa.active where sp.profile_id=target_profile and private.can_access_stage(ssa.stage));
  end if;
  if r='supervisor' then
    sup:=private.current_supervisor_id();
    return exists(select 1 from public.schools s left join public.teacher_records tr on tr.home_school_id=s.id where s.supervisor_id=sup and (s.manager_profile_id=target_profile or tr.profile_id=target_profile));
  end if;
  if r='school_manager' then
    select id into hs from public.schools where manager_profile_id=auth.uid() limit 1;
    return exists(select 1 from public.teacher_records tr where tr.home_school_id=hs and tr.profile_id=target_profile);
  end if;
  if r='senior_teacher' then
    hs:=private.current_home_school_id();
    return exists(select 1 from public.teacher_records tr where tr.home_school_id=hs and tr.profile_id=target_profile);
  end if;
  return false;
end$function$;

drop policy if exists sss_read on public.supervisor_school_subjects;
drop policy if exists sss_insert on public.supervisor_school_subjects;
drop policy if exists sss_update on public.supervisor_school_subjects;
drop function if exists private.supervises_school(uuid,uuid);
-- إلغاء إسناد مرحلة «ثانوي» لشيماء محمد فرج (أُضيف مع v208)
update public.supervisor_stage_assignments set active=false where supervisor_id='54161bac-29ed-4276-a0e0-a45b23ca4b8e' and stage='ثانوي';
