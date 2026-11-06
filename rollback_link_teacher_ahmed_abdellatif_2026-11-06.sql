-- استرجاع ربط «احمد عبداللطيف احمد محمد» بالمفرجية الابتدائية تعليم اساسي (2026-11-06) — يعيده بلا مدرسة أصلية كما كان
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- النسخة الاحتياطية: private.backup_teacher_ahmed_abdellatif_2026_11_06
update public.teacher_school_assignments set active=false, is_home_school=false
 where teacher_id='9701afcb-2f31-4691-93fc-732cac6cb738' and school_id='5890e7f3-dced-429b-aa42-5cc238dd375f';
update public.teacher_records set home_school_id=null where id='9701afcb-2f31-4691-93fc-732cac6cb738';
