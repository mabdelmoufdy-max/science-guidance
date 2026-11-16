-- استرجاع v393 (أرشفة ملفات التخزين): يزيل الجدول والدوال الجديدة فقط ولا يمس أي ملف في التخزين.
-- تنبيه: إن كانت هناك ملفات في السلة (_trash/) فأعدها لمكانها من شاشة «طلبات معلمي الأجر» (زر استرجاع) قبل تشغيل هذا الملف.
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- ما يُتوقع: «Success. No rows returned».

drop function if exists public.service_files_current(text, text[]);
drop function if exists public.admin_files_log_download(text, jsonb, text);
drop function if exists public.admin_files_status(text);
drop function if exists private.v393_check(text);
drop table if exists public.file_archive_log;
