-- v324: حفظ الجدول للموجه/المنسق/مدير المدرسة — كان SELECT ... FOR UPDATE على teaching_assignments
-- يُرفض بـRLS (لا سياسة UPDATE لهذه الأدوار) فتظهر «الإسناد غير موجود أو خارج صلاحيتك».
-- الدالة تعمل بصلاحية النظام؛ فحص private.timetable_can_manage قبل القراءة وبعدها باقٍ كما هو.
alter function private.validate_timetable_slot() security definer;
