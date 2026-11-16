-- استرجاع v392 (صحيفة الأحوال الإلكترونية للمعلم): هجرة إضافية فقط، فالاسترجاع يزيل الكائنات الجديدة ولا يمس أي شيء قائم.
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- تنبيه: الملفات المرفوعة في حاوية teacher-statements لا تُحذف من هنا (الحذف من لوحة Storage أو من شاشة التفريغ في المرحلة 2).
-- ما يُتوقع: «Success. No rows returned».

drop function if exists public.admin_set_statement_stage(text, boolean);
drop function if exists public.admin_statements_overview();
drop function if exists public.service_statement_record(uuid, text, text, integer);
drop function if exists public.service_statement_prepare(text, text);
drop function if exists public.teacher_portal_statement_status(text, text);
drop function if exists private.v392_ctx(text, text);
drop policy if exists statements_select_admin on storage.objects;
drop table if exists public.statement_stage_settings;
drop table if exists public.teacher_statements;
-- (لإزالة الحاوية نفسها بعد تفريغها من لوحة Storage: delete from storage.buckets where id = 'teacher-statements';)
