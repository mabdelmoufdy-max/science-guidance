-- استرجاع v387: يلغي دوال إضافة/حذف الفصول من بوابة المعلمين (لا يمس الفصول المضافة أو المحذوفة سابقًا)
drop function if exists public.teacher_portal_sup_remove_class(text,text,uuid,uuid);
drop function if exists public.teacher_portal_sup_add_class(text,text,uuid,text,text);
drop function if exists public.teacher_portal_class_options(text,text,uuid);
drop function if exists private.v387_sec_types(boolean,text);
-- المفتاح classes_open يُترك (لا أثر له بدون الدوال)؛ لإغلاق الإضافة/الحذف مؤقتًا بدل الاسترجاع:
--   update public.teacher_portal_settings set classes_open=false where id=1;
