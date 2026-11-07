-- استرجاع v295: يلغي الدالة فقط (شغّله في SQL Editor).
-- استرجاع معلم حُذف: بياناته كاملة في audit_log حيث action='admin_remove_teacher' و entity_id=<teacher id>
-- (old_data->'teacher' وروابطه)؛ يُعاد إدراجها يدويًا عند الحاجة.
DROP FUNCTION IF EXISTS public.admin_remove_teacher(uuid);
