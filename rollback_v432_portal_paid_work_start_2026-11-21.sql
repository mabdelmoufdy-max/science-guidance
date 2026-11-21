-- v432 استرجاع (يُشغَّل من SQL Editor): يزيل الدالة والمفتاح فقط. التواريخ المعدّلة تُسترجع من audit_log (action=teacher_portal_paid_ws_set، old_data).
drop function if exists public.teacher_portal_paid_ws_set(text,text,date);
alter table public.teacher_portal_settings drop column if exists paid_ws_edit_open;
