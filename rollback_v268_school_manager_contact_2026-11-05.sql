-- استرجاع v268_school_manager_contact (2026-11-05)
-- يُشغَّل في SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يزيل دالة الحفظ وجدول اسم/هاتف مدير المدرسة. لا يمس schools ولا school_data_intake.
-- تحذير: ما سُجّل من أسماء وهواتف سيُفقد؛ احفظه أولًا إن لزم:
--   create table private.v268_backup_school_manager_contact as select * from public.school_manager_contact;
-- سجلات audit_log (action='set_school_manager_contact') تبقى للتاريخ.

drop function if exists public.set_school_manager_contact(uuid, text, text);
drop table if exists public.school_manager_contact;

-- المتوقع: نجاح بلا صفوف؛ ثم select to_regclass('public.school_manager_contact') يعيد null.
