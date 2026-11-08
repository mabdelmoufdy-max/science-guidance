-- حذف المعلمة «إيمان احمد محمد علي» — السادات الابتدائية بشنهور (بطلب المستخدم 2026-11-06)
-- ثابتة، بلا إسناد ولا انتداب ولا إجازة ولا حساب دخول، ولا يرتبط بسجلها أي جدول آخر.
-- نسخة احتياطية: private.backup_teacher_eman_sadat_2026_11_06 (سطر واحد).
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- المتوقع عند النجاح: Success / 1 row affected
delete from public.teacher_records
 where id='41bddc27-e103-4cde-a53a-b28cfcbc50ab' and full_name='إيمان احمد محمد علي';
