-- استرجاع v392b (استثناء معلم الأجر): يعيد تعريفات الدوال الأربع كما كانت في v392 (يشمل الأجر). لا يمس الجداول ولا الملفات.
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- ما يُتوقع: «Success. No rows returned».

-- 4) سياق الرفع المشترك: تحقق الرقم القومي والهاتف (tp_check) ثم مرحلة مدرسة المعلم الأصلية والمفتاح
create or replace function private.v392_ctx(p_civil text, p_phone text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
declare c jsonb; t public.teacher_records; v_stage text; v_open boolean; s public.teacher_statements;
begin
  c := private.tp_check(p_civil, p_phone);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['teacher_id', 'status', 'limited']);
  end if;
  if coalesce((c ->> 'limited')::boolean, false) then return jsonb_build_object('ok', false, 'reason', 'no_phone'); end if;
  select * into t from public.teacher_records where id = (c ->> 'teacher_id')::uuid;
  select sc.stage into v_stage from public.schools sc where sc.id = t.home_school_id;
  select ss.is_open into v_open from public.statement_stage_settings ss where ss.stage = v_stage;
  select * into s from public.teacher_statements where teacher_id = t.id;
  return jsonb_build_object('ok', true, 'teacher_id', t.id, 'stage', v_stage, 'open', coalesce(v_open, false),
    'status', s.status, 'uploaded_at', s.uploaded_at, 'file_size', s.file_size, 'mime', s.mime,
    'upload_count', coalesce(s.upload_count, 0), 'old_path', s.storage_path);
end $function$;
revoke all on function private.v392_ctx(text, text) from public, anon, authenticated;

-- 5) حالة المعلم في البوابة (بلا كشف معرّف المعلم)
create or replace function public.teacher_portal_statement_status(p_civil text, p_phone text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
declare x jsonb;
begin
  x := private.v392_ctx(p_civil, p_phone);
  if coalesce((x ->> 'ok')::boolean, false) is not true then return x; end if;
  return jsonb_build_object('ok', true, 'stage', x -> 'stage', 'open', x -> 'open', 'status', x -> 'status',
    'uploaded_at', x -> 'uploaded_at', 'file_size', x -> 'file_size', 'mime', x -> 'mime');
end $function$;
revoke all on function public.teacher_portal_statement_status(text, text) from public;
grant execute on function public.teacher_portal_statement_status(text, text) to anon, authenticated;

-- 6) لدالة الحافة فقط (مفتاح الخدمة): التحقق قبل الرفع وتسجيله بعده
create or replace function public.service_statement_prepare(p_civil text, p_phone text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
declare x jsonb;
begin
  x := private.v392_ctx(p_civil, p_phone);
  if coalesce((x ->> 'ok')::boolean, false) is not true then return x; end if;
  if coalesce((x ->> 'open')::boolean, false) is not true then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if coalesce((x ->> 'upload_count')::int, 0) >= 10 then return jsonb_build_object('ok', false, 'reason', 'too_many'); end if;
  return jsonb_build_object('ok', true, 'teacher_id', x -> 'teacher_id', 'old_path', x -> 'old_path');
end $function$;
revoke all on function public.service_statement_prepare(text, text) from public, anon, authenticated;
grant execute on function public.service_statement_prepare(text, text) to service_role;

create or replace function public.service_statement_record(p_teacher uuid, p_path text, p_mime text, p_size integer)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
begin
  insert into public.teacher_statements (teacher_id, storage_path, mime, file_size, status, upload_count, uploaded_at, archived_at)
  values (p_teacher, p_path, p_mime, p_size, 'uploaded', 1, now(), null)
  on conflict (teacher_id) do update set storage_path = excluded.storage_path, mime = excluded.mime, file_size = excluded.file_size,
    status = 'uploaded', upload_count = public.teacher_statements.upload_count + 1, uploaded_at = now(), archived_at = null;
  insert into public.audit_log (actor_role, action, entity_type, entity_id, new_data)
  values ('teacher', 'teacher_portal_statement_upload', 'teacher', p_teacher::text, jsonb_build_object('mime', p_mime, 'size', p_size));
  return jsonb_build_object('ok', true);
end $function$;
revoke all on function public.service_statement_record(uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.service_statement_record(uuid, text, text, integer) to service_role;

-- 7) لمدير النظام: النظرة العامة (المعلمون النشطون بمدرسة أصلية، دون المجازين إجازة مجددة — قاعدة v374) ومفتاح المراحل
create or replace function public.admin_statements_overview()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
begin
  perform private.v356_require_admin();
  return jsonb_build_object(
    'stages', (select coalesce(jsonb_agg(jsonb_build_object('stage', ss.stage, 'open', ss.is_open)
                 order by case ss.stage when 'ابتدائي' then 1 when 'إعدادي' then 2 when 'ثانوي عام' then 3 else 4 end), '[]'::jsonb)
               from public.statement_stage_settings ss),
    'rows', (select coalesce(jsonb_agg(jsonb_build_object('teacher_id', t.id, 'teacher_name', t.full_name, 'school_id', s.id,
                 'school_name', s.name, 'stage', s.stage, 'work_type', t.work_type, 'status', st.status,
                 'uploaded_at', st.uploaded_at, 'file_size', st.file_size, 'mime', st.mime, 'path', st.storage_path)
                 order by s.stage, s.name, t.full_name), '[]'::jsonb)
             from public.teacher_records t
             join public.schools s on s.id = t.home_school_id
             left join public.teacher_statements st on st.teacher_id = t.id
             where t.active
               and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id = l.academic_year_id and ay.is_active
                                where l.teacher_id = t.id and l.renewal_status = 'renewed')));
end $function$;
revoke all on function public.admin_statements_overview() from public, anon;
grant execute on function public.admin_statements_overview() to authenticated;

create or replace function public.admin_set_statement_stage(p_stage text, p_open boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
declare v_old boolean;
begin
  perform private.v356_require_admin();
  select is_open into v_old from public.statement_stage_settings where stage = p_stage;
  if not found then raise exception 'مرحلة غير معروفة' using errcode = '22023'; end if;
  update public.statement_stage_settings set is_open = coalesce(p_open, false), updated_at = now() where stage = p_stage;
  insert into public.audit_log (actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (auth.uid(), 'admin', 'statement_stage_toggle', 'statement_stage', p_stage, jsonb_build_object('open', v_old), jsonb_build_object('open', coalesce(p_open, false)));
  return jsonb_build_object('ok', true, 'stage', p_stage, 'open', coalesce(p_open, false));
end $function$;
revoke all on function public.admin_set_statement_stage(text, boolean) from public, anon;
grant execute on function public.admin_set_statement_stage(text, boolean) to authenticated;
