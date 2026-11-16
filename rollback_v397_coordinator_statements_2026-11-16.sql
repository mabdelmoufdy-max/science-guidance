-- استرجاع v397: يزيل إضافات المنسق فقط (الدالتان والسياسة والإجراء). لا يمس الصحائف المرفوعة ولا دوال المدير.
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- النتيجة المتوقعة: Success. No rows returned
drop policy if exists statements_select_coord on storage.objects;
drop function if exists private.coord_can_view_statement(text);
drop function if exists public.coordinator_statements_overview();
drop function if exists public.service_statement_coord_prepare(uuid, uuid);
drop function if exists public.service_statement_coord_record(uuid, uuid, text, text, integer);
delete from public.permission_rules where capability = 'statements.upload';
delete from public.permission_grants where capability = 'statements.upload';
delete from public.permission_capabilities where code = 'statements.upload';
-- ثم عطّل أو أعد نشر دالة الحافة coordinator-statement-upload (الاسترجاع: لا حاجة لها بعد حذف الدالتين).
