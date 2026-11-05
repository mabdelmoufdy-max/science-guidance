-- استرجاع v270: دالة تعديل الموجه لبياناته + عمود تاريخ الحصول على الدرجة
-- شغّله في: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- تنبيه: إسقاط العمود يمحو ما أدخله الموجهون في «تاريخ الحصول على الدرجة».
revoke execute on function public.update_my_supervisor_profile(text,text,text,date,date,date) from authenticated;
drop function if exists public.update_my_supervisor_profile(text,text,text,date,date,date);
alter table public.supervisors drop column if exists grade_date;
-- المتوقع: Success. No rows returned
