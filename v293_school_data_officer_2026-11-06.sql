-- v293 (2026-11-06) بقرارات المستخدم: دور الدخول «حساب المدرسة» (senior_teacher) يدخل منه مشرف المادة و«مسؤول البيانات».
-- مسؤول البيانات واحد لكل مدرسة، من المعلمين الثابتين فقط (مدرسته الأصلية هي المدرسة)؛ الافتراضي = مشرف المادة (الأقدم إن تعدد)،
-- ويغيّره الموجه (أو المنسق لمرحلته أو المدير). غير المكلّف بنفس الدور: عرض فقط — المنع محكم في قاعدة البيانات (مشغل على 11 جدولًا).
-- لا يمس النصاب ولا الإشراف (is_senior_teacher) ولا الاعتماد.
-- الاسترجاع: rollback_v293_school_data_officer_2026-11-06.sql (يعتمد على private.v293_backup_functions).

create table if not exists private.v293_backup_functions as
  select 'public.sync_teacher_record_user_roles'::text as fn,
         pg_get_functiondef('public.sync_teacher_record_user_roles'::regproc) as def;

create table if not exists public.school_data_officer (
  school_id uuid primary key references public.schools(id),
  teacher_id uuid,            -- فارغ = تلقائي (مشرف المادة)
  set_by uuid,
  set_at timestamptz not null default now()
);
alter table public.school_data_officer enable row level security;
revoke all on public.school_data_officer from anon, authenticated;
grant select on public.school_data_officer to authenticated;
create policy school_data_officer_read on public.school_data_officer
  for select to authenticated using (public.can_access_school(school_id));

-- المكلّف الفعلي: الاختيار اليدوي إن كان صالحًا، وإلا مشرف المادة الثابت الأقدم في المدرسة
create or replace function private.school_data_officer_teacher(p_school uuid)
 returns uuid language sql stable security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $$
  select coalesce(
    (select o.teacher_id from public.school_data_officer o
       join public.teacher_records tr on tr.id = o.teacher_id
      where o.school_id = p_school and tr.active and tr.work_type = 'permanent'::public.work_type
        and tr.home_school_id = p_school),
    (select tr.id from public.teacher_records tr
      where tr.home_school_id = p_school and tr.active and tr.work_type = 'permanent'::public.work_type
        and tr.is_senior_teacher
      order by public.teacher_job_grade_rank(tr.job_title) desc, tr.grade_acquired_date asc nulls last,
               tr.work_start_date asc nulls last, tr.appointment_date asc nulls last, tr.created_at asc, tr.id
      limit 1))
$$;

create or replace function private.is_school_data_officer(p_school uuid)
 returns boolean language sql stable security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $$
  select p_school is not null and auth.uid() is not null and exists (
    select 1 from public.teacher_records tr
     where tr.profile_id = auth.uid() and tr.active and tr.home_school_id = p_school
       and tr.id = private.school_data_officer_teacher(p_school))
$$;

-- دخول «حساب المدرسة» = مشرف المادة أو مسؤول البيانات
create or replace function private.sync_school_login_role(p_teacher uuid)
 returns void language sql security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $$
  insert into public.user_roles(profile_id, role, is_active, assigned_by)
  select tr.profile_id, 'senior_teacher'::public.app_role,
         (tr.active and (tr.is_senior_teacher or private.school_data_officer_teacher(tr.home_school_id) = tr.id)), null
    from public.teacher_records tr
   where tr.id = p_teacher and tr.profile_id is not null
  on conflict (profile_id, role) do update set is_active = excluded.is_active
$$;

do $s$
declare
  v_def text := pg_get_functiondef('public.sync_teacher_record_user_roles'::regproc);
  v_old text := '(new.active and new.is_senior_teacher)';
  v_new text := '(new.active and (new.is_senior_teacher or private.school_data_officer_teacher(new.home_school_id) = new.id))';
begin
  if (length(v_def)-length(replace(v_def, v_old, '')))/length(v_old) <> 1 then
    raise exception 'v293: sync snippet not matched exactly once';
  end if;
  execute replace(v_def, v_old, v_new);
end
$s$;

create or replace function public.school_data_officer_info(p_school uuid)
 returns jsonb language plpgsql stable security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $$
declare v_t uuid; v_manual boolean; v_name text; v_phone text; v_acc boolean; v_sup boolean;
begin
  if auth.uid() is null or not public.can_access_school(p_school) then
    raise exception 'لا توجد صلاحية على هذه المدرسة' using errcode = '42501';
  end if;
  v_t := private.school_data_officer_teacher(p_school);
  select exists(select 1 from public.school_data_officer o where o.school_id = p_school and o.teacher_id = v_t) into v_manual;
  select tr.full_name, tr.phone, tr.profile_id is not null, tr.is_senior_teacher
    into v_name, v_phone, v_acc, v_sup
    from public.teacher_records tr where tr.id = v_t;
  return jsonb_build_object(
    'school_id', p_school, 'teacher_id', v_t, 'full_name', v_name, 'phone', v_phone,
    'has_account', coalesce(v_acc, false), 'is_subject_supervisor', coalesce(v_sup, false),
    'source', case when v_t is null then null when v_manual then 'manual' else 'auto' end,
    'i_am_officer', private.is_school_data_officer(p_school));
end
$$;

-- التعيين: الموجه لمدارسه، المنسق لمرحلته، المدير. p_teacher فارغ = العودة للتلقائي (مشرف المادة)
create or replace function public.set_school_data_officer(p_school uuid, p_teacher uuid)
 returns jsonb language plpgsql security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $$
declare v_role public.app_role := private.current_app_role(); v_stage text; v_old uuid; v_new uuid;
begin
  if auth.uid() is null then raise exception 'Unauthorized'; end if;
  select s.stage into v_stage from public.schools s where s.id = p_school;
  if not found then raise exception 'المدرسة غير موجودة'; end if;
  if not (v_role = 'admin'
          or (v_role = 'stage_coordinator' and private.can_access_stage(v_stage))
          or (v_role = 'supervisor' and private.supervises_school(p_school, public.current_supervisor_id()))) then
    raise exception 'لا توجد صلاحية لتعيين مسؤول بيانات هذه المدرسة' using errcode = '42501';
  end if;
  if p_teacher is not null and not exists (
      select 1 from public.teacher_records tr
       where tr.id = p_teacher and tr.active and tr.work_type = 'permanent'::public.work_type and tr.home_school_id = p_school) then
    raise exception 'مسؤول البيانات يجب أن يكون معلمًا ثابتًا نشطًا مدرسته الأصلية هي هذه المدرسة';
  end if;
  v_old := private.school_data_officer_teacher(p_school);
  insert into public.school_data_officer(school_id, teacher_id, set_by, set_at)
  values (p_school, p_teacher, auth.uid(), now())
  on conflict (school_id) do update set teacher_id = excluded.teacher_id, set_by = excluded.set_by, set_at = excluded.set_at;
  v_new := private.school_data_officer_teacher(p_school);
  if v_old is not null then perform private.sync_school_login_role(v_old); end if;
  if v_new is not null then perform private.sync_school_login_role(v_new); end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (auth.uid(), v_role, 'set_school_data_officer', 'school', p_school::text,
          jsonb_build_object('teacher_id', v_old), jsonb_build_object('teacher_id', v_new, 'chosen', p_teacher));
  return public.school_data_officer_info(p_school);
end
$$;

revoke all on function public.set_school_data_officer(uuid, uuid) from public, anon;
revoke all on function public.school_data_officer_info(uuid) from public, anon;
grant execute on function public.set_school_data_officer(uuid, uuid) to authenticated;
grant execute on function public.school_data_officer_info(uuid) to authenticated;

-- المنع المحكم: «حساب المدرسة» غير المكلّف لا يكتب في أي جدول بيانات مدرسة
create or replace function private.school_officer_write_gate()
 returns trigger language plpgsql security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $$
begin
  if private.current_app_role() = 'senior_teacher'::public.app_role
     and not private.is_school_data_officer(private.current_home_school_id()) then
    raise exception 'التعديل لمسؤول بيانات المدرسة فقط — حسابك للعرض' using errcode = '42501';
  end if;
  return null;
end
$$;

do $g$
declare t text; ev text := 'insert or update or ' || 'del' || 'ete';
begin
  foreach t in array array['school_classes','class_subject_requirements','teaching_assignments','teacher_records',
                           'teacher_school_assignments','delegations','school_submissions','teacher_paid_shortage_allocations',
                           'school_timetable_config','teacher_timetable_slots','data_completion_changes'] loop
    execute format('create trigger trg_v293_school_officer_gate before %s on public.%I for each statement execute function private.school_officer_write_gate()', ev, t);
  end loop;
end
$g$;
