-- استرجاع v427: يحذف الدوال الثلاث الجديدة (ما حُفظ من بيانات يبقى؛ القيم السابقة لبيانات المدرسة في audit_log action=teacher_portal_sup_school_update).
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new — عند النجاح: «Success. No rows returned».
-- إيقاف فقط بلا حذف: update teacher_portal_settings set school_edit_open=false where id=1;
drop function if exists public.teacher_portal_sup_school_details(text, text);
drop function if exists public.teacher_portal_sup_school_update(text, text, jsonb);
drop function if exists public.teacher_portal_sup_fill_missing(text, text, uuid, jsonb);
