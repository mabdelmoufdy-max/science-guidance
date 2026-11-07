-- استرجاع إغلاق تسجيل البيانات من بوابة المعلمين (2026-11-07): يعيد فتح التسجيل والتعديل كما كان.
-- البديل الأسهل: زر فتح/إغلاق التعديل في صفحة الاعتماد (teacher-portal-admin.vercel.app) — يستدعي teacher_portal_admin_settings.
update public.teacher_portal_settings set editing_open = true, note = null, updated_at = now() where id = 1;
-- المتوقع: سطر واحد محدَّث؛ و select public.teacher_portal_status()->>'editing_open' يعيد true.
