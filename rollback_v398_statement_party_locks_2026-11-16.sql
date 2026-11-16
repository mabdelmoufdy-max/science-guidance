-- استرجاع v398 (قفل رفع صحائف الأحوال المنفصل للمنسق والمعلم).
-- يعيد نص الدوال الثلاث من النسخة الاحتياطية، ثم يزيل الدالة الجديدة والعمود الجديد.
-- يُشغَّل من SQL Editor لأنه يحتوي أمر إزالة (أداة Supabase في جلسات Claude تتوقف عنده):
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- بعد الاسترجاع يعود مفتاح واحد لكل مرحلة (is_open) يحكم المعلم والمنسق معًا.
-- لا تحذف private.v398_backup_functions / private.v398_backup_settings.
do $do$
declare r record;
begin
  for r in select def from private.v398_backup_functions loop
    execute r.def;
  end loop;
end $do$;
drop function if exists public.admin_set_statement_party(text, text, boolean);
alter table public.statement_stage_settings drop column if exists coordinator_open;
-- المتوقع عند النجاح: select stage, is_open from public.statement_stage_settings; ← 4 صفوف (قيم is_open كما هي).
