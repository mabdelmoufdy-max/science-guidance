-- (اختياري) تنظيف متطلبات الحصص الصفرية في مجموعات الثالث الثانوي المضافة، لتصير لكل مجموعة مادة واحدة كبقية المجموعات
delete from public.class_subject_requirements r
 using public.bak_added_classes_2026_10_28 b
 where r.class_id=b.class_id and r.weekly_periods=0
returning r.class_id;
