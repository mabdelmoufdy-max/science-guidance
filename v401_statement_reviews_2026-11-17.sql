-- v401: مراجعة صحائف الأحوال «بالعين» — حفظ نتيجة مقارنة صحيفة كل معلم ببياناته في البرنامج.
-- إضافي فقط: جدول جديد + دالتان للمدير ومنسق المرحلة (لمراحله) + إضافة حقول المراجعة لصفوف دالتي الاطلاع.
-- لا تعديل تلقائي لأي بيان للمعلم؛ الفروق تُسجَّل فقط.

-- 1) نسخ احتياطية (لا تُحذف؛ يعتمد عليها ملف الاسترجاع)
create table if not exists private.v401_backup_functions as
select p.proname::text as proname, pg_get_functiondef(p.oid) as def
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('admin_statements_overview', 'coordinator_statements_overview');

-- 2) الجدول (بلا سياسات ولا صلاحيات مباشرة: الدخول بالدوال فقط)
create table if not exists public.teacher_statement_reviews (
  teacher_id uuid primary key,
  status text not null check (status in ('match', 'diff')),
  fields jsonb not null default '[]'::jsonb,
  diffs jsonb not null default '[]'::jsonb,
  diff_count integer not null default 0,
  note text,
  st_uploaded_at timestamptz,
  reviewed_by uuid,
  reviewed_by_name text,
  reviewed_at timestamptz not null default now()
);
alter table public.teacher_statement_reviews enable row level security;
revoke all on public.teacher_statement_reviews from public, anon, authenticated;

-- 3) فحص الصلاحية: مدير النظام (الدور النشط) أو منسق المرحلة لمعلمي مراحله فقط
create or replace function private.v401_check(p_teacher uuid)
returns void
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare v_role text := private.current_app_role()::text; v_uid uuid := auth.uid(); v_stage text;
begin
  if v_uid is null then raise exception 'غير مصرح' using errcode = '42501'; end if;
  if v_role = 'admin' then
    perform private.v356_require_admin();
    return;
  elsif v_role = 'stage_coordinator' then
    if not exists (select 1 from public.user_roles ur where ur.profile_id = v_uid and ur.role::text = 'stage_coordinator' and ur.is_active) then
      raise exception 'غير مصرح' using errcode = '42501';
    end if;
    select sc.stage into v_stage from public.teacher_records t join public.schools sc on sc.id = t.home_school_id where t.id = p_teacher;
    if v_stage is null or not exists (
         select 1 from public.stage_coordinator_assignments sca join public.supervisors sp on sp.id = sca.supervisor_id and sp.active
          where sp.profile_id = v_uid and sca.active and sca.stage = v_stage) then
      raise exception 'هذا المعلم خارج مراحلك' using errcode = '42501';
    end if;
    return;
  end if;
  raise exception 'هذه العملية لمدير النظام ومنسق المرحلة فقط' using errcode = '42501';
end $fn$;

-- 4) القيم المسجلة في البرنامج للحقول المقارَنة (نصوص جاهزة للعرض)
create or replace function private.v401_ours(p_teacher uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
  select jsonb_build_array(
    jsonb_build_object('k', 'name', 'label', 'الاسم', 'ours', coalesce(t.full_name, '')),
    jsonb_build_object('k', 'civil_id', 'label', 'الرقم القومي', 'ours', coalesce(t.civil_id, '')),
    jsonb_build_object('k', 'job_title', 'label', 'الدرجة الوظيفية', 'ours', coalesce(t.job_title, '')),
    jsonb_build_object('k', 'appointment_date', 'label', 'تاريخ التعيين', 'ours', coalesce(to_char(t.appointment_date, 'DD/MM/YYYY'), '')),
    jsonb_build_object('k', 'grade_date', 'label', 'التاريخ الاعتباري', 'ours', coalesce(to_char(t.grade_acquired_date, 'DD/MM/YYYY'), '')),
    jsonb_build_object('k', 'qualification', 'label', 'المؤهل', 'ours', trim(coalesce(t.qualification, '') || case when t.qualification_year is not null then ' — ' || t.qualification_year::text else '' end)),
    jsonb_build_object('k', 'school', 'label', 'المدرسة', 'ours', coalesce(sc.name, '')))
  from public.teacher_records t left join public.schools sc on sc.id = t.home_school_id where t.id = p_teacher
$fn$;

-- 5) قراءة: بيانات المعلم + حالة مراجعته (تُعتبر قديمة إن استُبدلت الصحيفة بعدها)
create or replace function public.statement_review_get(p_teacher uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare t public.teacher_records; s public.teacher_statements; r public.teacher_statement_reviews; v_ours jsonb; v_stale boolean; v_fields jsonb;
begin
  perform private.v401_check(p_teacher);
  select * into t from public.teacher_records where id = p_teacher and active;
  if not found then raise exception 'المعلم غير موجود أو غير نشط' using errcode = '22023'; end if;
  select * into s from public.teacher_statements where teacher_id = p_teacher;
  select * into r from public.teacher_statement_reviews where teacher_id = p_teacher;
  v_ours := private.v401_ours(p_teacher);
  v_stale := r.teacher_id is not null and r.st_uploaded_at is distinct from s.uploaded_at;
  select coalesce(jsonb_agg(jsonb_build_object('k', o ->> 'k', 'label', o ->> 'label', 'ours', o ->> 'ours',
           'state', case when r.teacher_id is null or v_stale then null else (select f ->> 'state' from jsonb_array_elements(r.fields) f where f ->> 'k' = o ->> 'k' limit 1) end,
           'theirs', case when r.teacher_id is null or v_stale then null else (select f ->> 'theirs' from jsonb_array_elements(r.fields) f where f ->> 'k' = o ->> 'k' limit 1) end)
           order by ord), '[]'::jsonb) into v_fields
    from jsonb_array_elements(v_ours) with ordinality as x(o, ord);
  return jsonb_build_object('ok', true, 'teacher_name', t.full_name,
    'statement', jsonb_build_object('path', s.storage_path, 'mime', s.mime, 'status', s.status, 'uploaded_at', s.uploaded_at),
    'fields', v_fields, 'note', case when v_stale then null else r.note end,
    'status', case when r.teacher_id is null then null when v_stale then 'stale' else r.status end,
    'reviewed_at', r.reviewed_at, 'reviewed_by', r.reviewed_by_name);
end $fn$;

-- 6) حفظ المراجعة: لكل حقل ok | diff (مع القيمة المطبوعة في الصحيفة) | skip
create or replace function public.statement_review_save(p_teacher uuid, p_fields jsonb, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare s public.teacher_statements; v_ours jsonb; v_in jsonb; o jsonb; f jsonb; v_fields jsonb := '[]'::jsonb; v_diffs jsonb := '[]'::jsonb;
        v_state text; v_theirs text; v_ok int := 0; v_diff int := 0; v_status text; v_uid uuid := auth.uid(); v_name text;
begin
  perform private.v401_check(p_teacher);
  if jsonb_typeof(coalesce(p_fields, 'null'::jsonb)) is distinct from 'array' then raise exception 'بيانات المراجعة غير صالحة' using errcode = '22023'; end if;
  select * into s from public.teacher_statements where teacher_id = p_teacher;
  if not found then raise exception 'لا توجد صحيفة مرفوعة لهذا المعلم' using errcode = '22023'; end if;
  if not exists (select 1 from public.teacher_records t where t.id = p_teacher and t.active) then raise exception 'المعلم غير موجود أو غير نشط' using errcode = '22023'; end if;
  v_ours := private.v401_ours(p_teacher);
  for f in select * from jsonb_array_elements(p_fields) loop
    if not exists (select 1 from jsonb_array_elements(v_ours) x where x ->> 'k' = f ->> 'k') then raise exception 'حقل غير معروف' using errcode = '22023'; end if;
    if coalesce(f ->> 'state', '') not in ('ok', 'diff', 'skip') then raise exception 'حالة حقل غير صالحة' using errcode = '22023'; end if;
  end loop;
  for o in select * from jsonb_array_elements(v_ours) loop
    select pf into v_in from jsonb_array_elements(p_fields) pf where pf ->> 'k' = o ->> 'k' limit 1;
    v_state := coalesce(v_in ->> 'state', 'skip');
    v_theirs := left(trim(translate(coalesce(v_in ->> 'theirs', ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')), 200);
    if v_state = 'ok' then v_ok := v_ok + 1; v_theirs := ''; end if;
    if v_state = 'skip' then v_theirs := ''; end if;
    if v_state = 'diff' then
      v_diff := v_diff + 1;
      v_diffs := v_diffs || jsonb_build_array(jsonb_build_object('k', o ->> 'k', 'label', o ->> 'label', 'ours', o ->> 'ours', 'theirs', v_theirs));
    end if;
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('k', o ->> 'k', 'label', o ->> 'label', 'ours', o ->> 'ours', 'state', v_state, 'theirs', v_theirs));
  end loop;
  if v_ok + v_diff = 0 then raise exception 'لم تراجع أي حقل بعد' using errcode = '22023'; end if;
  v_status := case when v_diff > 0 then 'diff' else 'match' end;
  select p.full_name into v_name from public.profiles p where p.id = v_uid;
  insert into public.teacher_statement_reviews (teacher_id, status, fields, diffs, diff_count, note, st_uploaded_at, reviewed_by, reviewed_by_name, reviewed_at)
  values (p_teacher, v_status, v_fields, v_diffs, v_diff, nullif(left(trim(coalesce(p_note, '')), 500), ''), s.uploaded_at, v_uid, v_name, now())
  on conflict (teacher_id) do update set status = excluded.status, fields = excluded.fields, diffs = excluded.diffs, diff_count = excluded.diff_count,
    note = excluded.note, st_uploaded_at = excluded.st_uploaded_at, reviewed_by = excluded.reviewed_by, reviewed_by_name = excluded.reviewed_by_name, reviewed_at = excluded.reviewed_at;
  insert into public.audit_log (actor_profile_id, actor_role, action, entity_type, entity_id, new_data)
  values (v_uid, private.current_app_role(), 'statement_review', 'teacher', p_teacher::text, jsonb_build_object('status', v_status, 'diff_count', v_diff));
  return jsonb_build_object('ok', true, 'status', v_status, 'diff_count', v_diff);
end $fn$;
revoke all on function public.statement_review_get(uuid) from public, anon;
revoke all on function public.statement_review_save(uuid, jsonb, text) from public, anon;
grant execute on function public.statement_review_get(uuid) to authenticated, service_role;
grant execute on function public.statement_review_save(uuid, jsonb, text) to authenticated, service_role;

-- 7) صفوف دالتي الاطلاع (مدير + منسق): حالة المراجعة والفروق والملاحظة — تعديل نصي مرة واحدة بالضبط لكل دالة
do $do$
declare fn text; d text; n int; j1 text := 'left join public.teacher_statements st on st.teacher_id = t.id';
  j2 text := 'left join public.teacher_statements st on st.teacher_id = t.id left join public.teacher_statement_reviews rv on rv.teacher_id = t.id';
  a1 text := '''path'', st.storage_path)';
  a2 text := '''path'', st.storage_path, ''review_status'', case when rv.teacher_id is null then null when rv.st_uploaded_at is distinct from st.uploaded_at then ''stale'' else rv.status end, ''review_diffs'', case when rv.st_uploaded_at is not distinct from st.uploaded_at then rv.diffs end, ''review_note'', case when rv.st_uploaded_at is not distinct from st.uploaded_at then rv.note end)';
begin
  foreach fn in array array['public.admin_statements_overview()', 'public.coordinator_statements_overview()'] loop
    d := pg_get_functiondef(fn::regprocedure);
    n := (length(d) - length(replace(d, j1, ''))) / length(j1);
    if n <> 1 then raise exception 'v401: عدد مطابقات الربط % في %', n, fn; end if;
    n := (length(d) - length(replace(d, a1, ''))) / length(a1);
    if n <> 1 then raise exception 'v401: عدد مطابقات الحقول % في %', n, fn; end if;
    d := replace(replace(d, j1, j2), a1, a2);
    execute d;
  end loop;
end $do$;
