-- v227 (2026-10-30، بطلب المستخدم «نفذ البديل»): private.accessible_school_ids() بطلب جماعي واحد
-- بدل استدعاء can_access_school لكل مدرسة من الـ186. النتيجة مطابقة لـ«كل مدرسة يحقق لها can_access_school».
-- تستخدمها سياسات school_classes وclass_subject_requirements وteaching_assignments (v162).
-- تحقق: تجربة جافة 17 مستخدمًا (كل الأدوار النشطة) 0 فروق، 85 استدعاء 3.23ث←0.022ث؛ وبعد التطبيق 17/17 مطابقة لمنطق can_access_school.
-- الاسترجاع: rollback_v227_accessible_school_ids_2026-10-30.sql
create or replace function private.accessible_school_ids() returns uuid[]
language plpgsql stable security definer set search_path to 'pg_catalog','private','public','pg_temp' as $function$
declare r public.app_role; v_uid uuid := auth.uid(); v_sup uuid; v uuid[];
begin
  if v_uid is null then return '{}'::uuid[]; end if;
  r := private.current_app_role();
  if r in ('admin','first_supervisor') then
    select array_agg(s.id) into v from public.schools s;
  elsif r = 'stage_coordinator' then
    select array_agg(s.id) into v from public.schools s
     where exists (select 1 from public.stage_coordinator_assignments sca join public.supervisors sp on sp.id = sca.supervisor_id
                    where sp.profile_id = v_uid and sp.active and sca.active and sca.stage = s.stage);
  elsif r = 'supervisor' then
    v_sup := private.current_supervisor_id();
    if v_sup is not null then
      select array_agg(s.id) into v from public.schools s
       where s.supervisor_id = v_sup
          or exists (select 1 from public.supervisor_school_subjects x where x.school_id = s.id and x.supervisor_id = v_sup and x.active);
    end if;
  elsif r = 'school_manager' then
    select array_agg(s.id) into v from public.schools s where s.manager_profile_id = v_uid;
  elsif r in ('senior_teacher','teacher') then
    select array_agg(s.id) into v from public.schools s
     where exists (select 1 from public.teacher_school_assignments tsa join public.teacher_records tr on tr.id = tsa.teacher_id
                    where tr.profile_id = v_uid and tsa.school_id = s.id and tsa.active)
        or s.id = (select private.current_home_school_id());
  end if;
  return coalesce(v, '{}'::uuid[]);
end $function$;
