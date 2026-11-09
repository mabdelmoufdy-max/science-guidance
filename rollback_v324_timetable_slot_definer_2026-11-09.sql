-- استرجاع v324: إعادة دالة التحقق للعمل بصلاحية المستخدم
alter function private.validate_timetable_slot() security invoker;
