-- استرجاع ربط «فاطمة عبد الشافى سالمان» بنجع رجب الابتدائية بالخرانقة (2026-11-06) — يعيدها بلا مدرسة أصلية كما كانت
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- النسختان الاحتياطيتان: private.backup_teacher_fatma_abdelshafy_2026_11_06 و private.backup_deleg_fatma_abdelshafy_2026_11_06
update public.teacher_school_assignments set active=false, is_home_school=false
 where teacher_id=(select id from public.teacher_records where civil_id='29704082701661')
   and school_id in ('42c31ac1-716b-4726-94a2-166303e7418a','ad8713d9-8352-4e1b-9fd7-9ad9662933db');
update public.delegations d set from_school_id=b.from_school_id from private.backup_deleg_fatma_abdelshafy_2026_11_06 b where b.id=d.id;
update public.teacher_records set home_school_id=null where civil_id='29704082701661';
