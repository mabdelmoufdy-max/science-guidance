-- استرجاع v381: إزالة دالة دمج السجلات المكررة (لا تمس أي بيانات).
-- ملاحظة: أي دمج نُفّذ بها محفوظ كاملًا في audit_log (action = admin_merge_teachers، old_data = لقطة السجل المحذوف وروابطه).
drop function if exists public.admin_merge_teachers(uuid, uuid, text);
