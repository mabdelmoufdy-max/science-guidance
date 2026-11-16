-- v397: منسق المرحلة يطّلع على صحائف الأحوال لمراحله ويرفع أو يستبدل صحيفة معلم (بلا حذف ولا تفريغ).
-- إضافي فقط: لا يمس دوال المدير ولا سياساته ولا رفع المعلم. التفريغ والأرشفة وفتح/إغلاق المراحل تبقى للمدير وحده.

-- 1) إجراء جديد في مصفوفة الصلاحيات (مسموح افتراضيًا؛ يُمنع من مركز التحكم)
insert into public.permission_capabilities (code, label, description, sort, kind)
select 'statements.upload', 'رفع صحائف الأحوال',
       'رفع أو استبدال صحيفة الأحوال الإلكترونية لمعلم من مراحل المنسق (الاطلاع عليها لا يتأثر بهذا الإجراء)', 135, 'restrict'
where not exists (select 1 from public.permission_capabilities where code = 'statements.upload');

insert into public.permission_rules (capability, role, allowed)
select 'statements.upload', r::public.app_role, true
from unnest(array['first_supervisor','school_manager','senior_teacher','stage_coordinator','supervisor','teacher']) r
where not exists (select 1 from public.permission_rules x where x.capability = 'statements.upload' and x.role::text = r);

-- 2) قراءة: حالة معلمي مراحل المنسق فقط (نفس شكل admin_statements_overview)
create or replace function public.coordinator_statements_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare v_uid uuid := auth.uid(); v_stages text[];
begin
  if v_uid is null or private.current_app_role()::text is distinct from 'stage_coordinator' then
    raise exception 'هذه الشاشة لمنسق المرحلة (الدور النشط) فقط' using errcode = '42501';
  end if;
  select coalesce(array_agg(distinct sca.stage), '{}'::text[]) into v_stages
    from public.stage_coordinator_assignments sca
    join public.supervisors s on s.id = sca.supervisor_id
   where s.profile_id = v_uid and s.active and sca.active;
  return jsonb_build_object(
    'stages', (select coalesce(jsonb_agg(jsonb_build_object('stage', ss.stage, 'open', ss.is_open)
                 order by case ss.stage when 'ابتدائي' then 1 when 'إعدادي' then 2 when 'ثانوي عام' then 3 else 4 end), '[]'::jsonb)
               from public.statement_stage_settings ss where ss.stage = any(v_stages)),
    'upload_allowed', private.cap_allowed_for(v_uid, 'stage_coordinator', 'statements.upload'),
    'rows', (select coalesce(jsonb_agg(jsonb_build_object('teacher_id', t.id, 'teacher_name', t.full_name, 'school_id', s.id,
                 'school_name', s.name, 'stage', s.stage, 'work_type', t.work_type, 'status', st.status,
                 'uploaded_at', st.uploaded_at, 'file_size', st.file_size, 'mime', st.mime, 'path', st.storage_path)
                 order by s.stage, s.name, t.full_name), '[]'::jsonb)
             from public.teacher_records t
             join public.schools s on s.id = t.home_school_id
             left join public.teacher_statements st on st.teacher_id = t.id
             where t.active
               and s.stage = any(v_stages)
               and t.work_type is distinct from 'paid'
               and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id = l.academic_year_id and ay.is_active
                                where l.teacher_id = t.id and l.renewal_status = 'renewed')));
end $fn$;
revoke all on function public.coordinator_statements_overview() from public, anon;
grant execute on function public.coordinator_statements_overview() to authenticated, service_role;

-- 3) فتح الملف: المنسق (دوره في user_roles ومرحلته في إسناداته) يقرأ ملفات معلمي مراحله فقط
--    الفحص في دالة SECURITY DEFINER حتى لا تتأثر السياسة بسياسات القراءة على الجداول التي تقرؤها
create or replace function private.coord_can_view_statement(p_name text)
returns boolean
language sql
stable
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
  select auth.uid() is not null
    and exists (select 1 from public.user_roles ur where ur.profile_id = auth.uid() and ur.role::text = 'stage_coordinator' and ur.is_active)
    and exists (
      select 1 from public.teacher_records tr
      join public.schools sc on sc.id = tr.home_school_id
      join public.stage_coordinator_assignments sca on sca.stage = sc.stage and sca.active
      join public.supervisors sp on sp.id = sca.supervisor_id and sp.active
      where tr.id::text = (storage.foldername(p_name))[1] and sp.profile_id = auth.uid()
    );
$fn$;
grant execute on function private.coord_can_view_statement(text) to authenticated;

create policy statements_select_coord on storage.objects for select to authenticated
using (bucket_id = 'teacher-statements' and private.coord_can_view_statement(name));

-- 4) رفع المنسق بالنيابة (لمفتاح الخدمة فقط؛ تستدعيها دالة الحافة coordinator-statement-upload)
create or replace function public.service_statement_coord_prepare(p_actor uuid, p_teacher uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare t public.teacher_records; v_stage text; v_open boolean; s public.teacher_statements;
begin
  if p_actor is null or p_teacher is null then return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  if not exists (select 1 from public.profiles p where p.id = p_actor and p.is_active)
     or not exists (select 1 from public.user_roles ur where ur.profile_id = p_actor and ur.role::text = 'stage_coordinator' and ur.is_active) then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  if not private.cap_allowed_for(p_actor, 'stage_coordinator', 'statements.upload') then
    return jsonb_build_object('ok', false, 'reason', 'cap_blocked');
  end if;
  select * into t from public.teacher_records where id = p_teacher and active;
  if not found then return jsonb_build_object('ok', false, 'reason', 'no_teacher'); end if;
  if t.work_type is not distinct from 'paid' then return jsonb_build_object('ok', false, 'reason', 'not_applicable'); end if;
  select sc.stage into v_stage from public.schools sc where sc.id = t.home_school_id;
  if v_stage is null or not exists (
       select 1 from public.stage_coordinator_assignments sca join public.supervisors sp on sp.id = sca.supervisor_id and sp.active
        where sp.profile_id = p_actor and sca.active and sca.stage = v_stage) then
    return jsonb_build_object('ok', false, 'reason', 'out_of_scope');
  end if;
  select ss.is_open into v_open from public.statement_stage_settings ss where ss.stage = v_stage;
  if coalesce(v_open, false) is not true then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  select * into s from public.teacher_statements where teacher_id = t.id;
  if coalesce(s.upload_count, 0) >= 10 then return jsonb_build_object('ok', false, 'reason', 'too_many'); end if;
  return jsonb_build_object('ok', true, 'teacher_id', t.id, 'old_path', s.storage_path);
end $fn$;

create or replace function public.service_statement_coord_record(p_actor uuid, p_teacher uuid, p_path text, p_mime text, p_size integer)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
begin
  insert into public.teacher_statements (teacher_id, storage_path, mime, file_size, status, upload_count, uploaded_at, archived_at)
  values (p_teacher, p_path, p_mime, p_size, 'uploaded', 1, now(), null)
  on conflict (teacher_id) do update set storage_path = excluded.storage_path, mime = excluded.mime, file_size = excluded.file_size,
    status = 'uploaded', upload_count = public.teacher_statements.upload_count + 1, uploaded_at = now(), archived_at = null;
  insert into public.audit_log (actor_profile_id, actor_role, action, entity_type, entity_id, new_data)
  values (p_actor, 'stage_coordinator', 'coordinator_statement_upload', 'teacher', p_teacher::text, jsonb_build_object('mime', p_mime, 'size', p_size));
  return jsonb_build_object('ok', true);
end $fn$;

revoke all on function public.service_statement_coord_prepare(uuid, uuid) from public, anon, authenticated;
revoke all on function public.service_statement_coord_record(uuid, uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.service_statement_coord_prepare(uuid, uuid) to service_role;
grant execute on function public.service_statement_coord_record(uuid, uuid, text, text, integer) to service_role;
