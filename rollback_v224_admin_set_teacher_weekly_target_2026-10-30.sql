-- استرجاع v224: يحذف دالة النصاب المخفض فقط (القيم التي حُفظت بها في teacher_records.weekly_target_override تبقى كما هي؛
-- لإعادة معلم إلى نصاب درجته: update public.teacher_records set weekly_target_override = null where id = '<teacher_id>';)
drop function if exists public.admin_set_teacher_weekly_target(uuid, integer);
