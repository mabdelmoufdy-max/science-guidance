-- استرجاع إضافة 75 مجموعة للصف الثالث الثانوي (2026-10-28): يحذف المجموعات المضافة (معرّفاتها في bak_added_classes_2026_10_28)
-- ثم أعد عدد الفصول المسجل للمدارس (الأرقام القديمة أدناه). شغّله من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
delete from public.school_classes where id in (select class_id from public.bak_added_classes_2026_10_28) and not exists (select 1 from public.teaching_assignments a where a.class_id=school_classes.id);
-- أعداد الفصول المسجلة قبل الضبط: العسكرية 43، الشهداء 18 (كانت 37)، السكر وشنهور وخالد وخزام والحراجية وجراجوس وحجازة: راجع جدول الفروق في المحادثة
