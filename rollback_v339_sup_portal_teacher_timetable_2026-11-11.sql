-- استرجاع v339: إزالة دالتي جدول المعلم لمشرف المدرسة في بوابة المعلمين.
-- لا يمس الحصص المحفوظة في teacher_timetable_slots (ما أدخله المشرفون يبقى، ويستطيع المعلم تعديله من شاشته).
-- التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- المتوقع عند النجاح: Success. No rows returned
drop function if exists public.teacher_portal_sup_timetable_save(text, text, uuid, jsonb);
drop function if exists public.teacher_portal_sup_timetable_get(text, text, uuid);
