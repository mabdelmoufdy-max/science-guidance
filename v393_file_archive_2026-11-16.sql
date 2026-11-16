-- v393: أرشفة ملفات التخزين — تنزيل (ZIP على جهاز المدير) ← نقل إلى سلة مؤقتة (قابل للاسترجاع) ← إزالة نهائية.
-- بقرار المستخدم 2026-11-16: التجربة الأولى على ملفات طلبات معلمي الأجر (حاوية paid-teacher-docs)، ثم تُعمَّم على صحائف الأحوال (teacher-statements).
-- هجرة إضافية فقط: جدول سجل + دوال قراءة/تسجيل لمدير النظام + دالة تحقق لدالة الحافة. النقل والإزالة الفعليان بدالة الحافة admin-files-purge عبر واجهة Storage.

create table public.file_archive_log (
  bucket_id text not null,
  path text not null,
  size bigint not null,
  sha256 text,
  state text not null default 'downloaded' check (state in ('downloaded', 'quarantined', 'removed')),
  zip_name text,
  downloaded_at timestamptz not null default now(),
  downloaded_by uuid,
  trash_path text,
  quarantined_at timestamptz,
  removed_at timestamptz,
  primary key (bucket_id, path)
);
alter table public.file_archive_log enable row level security;
revoke all on public.file_archive_log from anon, authenticated;

-- صلاحية: مدير النظام (الدور النشط) وحاوية مسموحة؛ وملفات الأجر لمن في paid_teacher_viewers فقط
create or replace function private.v393_check(p_bucket text)
returns void language plpgsql stable security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
begin
  perform private.v356_require_admin();
  if p_bucket not in ('paid-teacher-docs', 'teacher-statements') then
    raise exception 'حاوية غير مسموحة' using errcode = '22023';
  end if;
  if p_bucket = 'paid-teacher-docs' and not public.paid_teacher_is_viewer() then
    raise exception 'غير مصرح: لست ضمن من يحق لهم عرض ملفات طلبات الأجر' using errcode = '42501';
  end if;
end $function$;
revoke all on function private.v393_check(text) from public, anon, authenticated;

-- حالة الحاوية: الملفات الحية (خارج السلة) بحالة كل ملف + ما في السلة أو أُزيل
create or replace function public.admin_files_status(p_bucket text)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
begin
  perform private.v393_check(p_bucket);
  return jsonb_build_object(
    'files', (select coalesce(jsonb_agg(jsonb_build_object('path', o.name, 'size', (o.metadata ->> 'size')::bigint,
                'created_at', o.created_at, 'state', l.state, 'sha256', l.sha256) order by o.name), '[]'::jsonb)
              from storage.objects o
              left join public.file_archive_log l on l.bucket_id = o.bucket_id and l.path = o.name
              where o.bucket_id = p_bucket and o.name not like '\_trash/%' escape '\'),
    'archive', (select coalesce(jsonb_agg(jsonb_build_object('path', l.path, 'size', l.size, 'state', l.state,
                'trash_path', l.trash_path, 'quarantined_at', l.quarantined_at, 'removed_at', l.removed_at) order by l.path), '[]'::jsonb)
                from public.file_archive_log l where l.bucket_id = p_bucket and l.state in ('quarantined', 'removed')));
end $function$;
revoke all on function public.admin_files_status(text) from public, anon;
grant execute on function public.admin_files_status(text) to authenticated;

-- تسجيل التنزيل: يتحقق الخادم أن كل ملف موجود بالحجم نفسه الذي أبلغه المتصفح
create or replace function public.admin_files_log_download(p_bucket text, p_items jsonb, p_zip text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
declare it jsonb; n int := 0; bad text[] := '{}'; sz bigint; pth text;
begin
  perform private.v393_check(p_bucket);
  if p_items is null or jsonb_typeof(p_items) <> 'array' then raise exception 'قائمة ملفات غير صالحة' using errcode = '22023'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    pth := it ->> 'path';
    sz := null;
    if pth is null or pth like '\_trash/%' escape '\' then bad := bad || coalesce(pth, '?'); continue; end if;
    select (o.metadata ->> 'size')::bigint into sz from storage.objects o where o.bucket_id = p_bucket and o.name = pth;
    if sz is null or sz <> coalesce((it ->> 'size')::bigint, -1) then bad := bad || pth; continue; end if;
    insert into public.file_archive_log (bucket_id, path, size, sha256, state, zip_name, downloaded_at, downloaded_by)
    values (p_bucket, pth, sz, it ->> 'sha256', 'downloaded', p_zip, now(), auth.uid())
    on conflict (bucket_id, path) do update
      set size = excluded.size, sha256 = excluded.sha256, zip_name = excluded.zip_name, downloaded_at = now(), downloaded_by = auth.uid()
      where public.file_archive_log.state = 'downloaded';
    n := n + 1;
  end loop;
  insert into public.audit_log (actor_profile_id, actor_role, action, entity_type, entity_id, new_data)
  values (auth.uid(), 'admin', 'files_download_logged', 'storage_files', p_bucket,
          jsonb_build_object('count', n, 'zip', p_zip, 'mismatched', cardinality(bad)));
  return jsonb_build_object('ok', true, 'logged', n, 'mismatched', to_jsonb(bad));
end $function$;
revoke all on function public.admin_files_log_download(text, jsonb, text) from public, anon;
grant execute on function public.admin_files_log_download(text, jsonb, text) to authenticated;

-- لدالة الحافة فقط (مفتاح الخدمة): الملفات الموجودة فعلًا وأحجامها
create or replace function public.service_files_current(p_bucket text, p_paths text[])
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public', 'pg_temp' as $function$
  select coalesce(jsonb_agg(jsonb_build_object('path', o.name, 'size', (o.metadata ->> 'size')::bigint)), '[]'::jsonb)
  from storage.objects o where o.bucket_id = p_bucket and o.name = any(p_paths)
$function$;
revoke all on function public.service_files_current(text, text[]) from public, anon, authenticated;
grant execute on function public.service_files_current(text, text[]) to service_role;
