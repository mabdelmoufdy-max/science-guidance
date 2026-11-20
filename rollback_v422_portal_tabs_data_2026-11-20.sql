-- استرجاع v422 (بوابة بتبويبات — المرحلة 1). يُشغَّل من SQL Editor:
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يعيد الدوال الثلاث من private.v422_backup_functions ويحذف دالة المتابعة.
-- الأعمدة السبعة تُترك (تحوي ما أدخله المعلمون)؛ احذفها فقط إن أردت محو تلك البيانات (السطر المعلّق آخر الملف).

do $r$
declare f record;
begin
  for f in select fn, def from private.v422_backup_functions loop
    execute f.def;
  end loop;
end
$r$;

drop function if exists public.teacher_portal_sup_timetable_overview(text, text);

-- عند النجاح: «Success. No rows returned».
-- اختياري (يمحو البيانات المدخلة):
-- alter table public.teacher_records drop column religion, drop column nationality, drop column marital_status,
--   drop column qualification_type, drop column qualification_issuer, drop column qualification_grade, drop column qualification_date;
