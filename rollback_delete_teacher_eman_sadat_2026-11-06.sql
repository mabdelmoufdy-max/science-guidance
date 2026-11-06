-- استرجاع حذف «إيمان احمد محمد علي» (السادات الابتدائية بشنهور) من النسخة الاحتياطية
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- المتوقع عند النجاح: 1 row affected، وتعود المعلمة في معلمي المدرسة.
insert into public.teacher_records select * from private.backup_teacher_eman_sadat_2026_11_06
on conflict (id) do nothing;
