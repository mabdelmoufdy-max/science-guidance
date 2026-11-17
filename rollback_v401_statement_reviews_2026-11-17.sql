-- استرجاع v401 (مراجعة صحائف الأحوال بالعين).
-- يعيد الدالتين من النسخة الاحتياطية، ثم يزيل الدالتين الجديدتين والمساعدتين والجدول.
-- انتبه: إزالة الجدول تمحو نتائج المراجعات المحفوظة؛ صدّر ما تحتاجه من «تقرير الفروق» قبل التشغيل.
-- يُشغَّل من SQL Editor لأنه يحتوي أمر إزالة (أداة Supabase في جلسات Claude تتوقف عنده):
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- لا تحذف private.v401_backup_functions.
do $do$
declare r record;
begin
  for r in select def from private.v401_backup_functions loop
    execute r.def;
  end loop;
end $do$;
drop function if exists public.statement_review_save(uuid, jsonb, text);
drop function if exists public.statement_review_get(uuid);
drop function if exists private.v401_ours(uuid);
drop function if exists private.v401_check(uuid);
drop table if exists public.teacher_statement_reviews;
-- المتوقع عند النجاح: عودة شاشة «صحائف الأحوال» لما كانت عليه (بلا حقول المراجعة في الصفوف).
