-- استرجاع دمج سجلات «حازم عبد السلام خير» (الجزء الأول، 2026-11-06): يعيد السجلات الثلاثة وإسناداتها وروابطها وانتدابه كما كانت
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- النسخ الاحتياطية: private.backup_hazem_records_2026_11_06 / _ta_ / _tsa_ / _deleg_
update public.teacher_records t set home_school_id=b.home_school_id, active=b.active from private.backup_hazem_records_2026_11_06 b where b.id=t.id;
update public.teaching_assignments t set teacher_id=b.teacher_id from private.backup_hazem_ta_2026_11_06 b where b.id=t.id;
update public.teacher_school_assignments t set active=false
 where t.teacher_id in (select id from private.backup_hazem_records_2026_11_06)
   and not exists (select 1 from private.backup_hazem_tsa_2026_11_06 b where b.teacher_id=t.teacher_id and b.school_id=t.school_id and b.term_id=t.term_id);
update public.teacher_school_assignments t set active=b.active, is_home_school=b.is_home_school from private.backup_hazem_tsa_2026_11_06 b
 where b.teacher_id=t.teacher_id and b.school_id=t.school_id and b.term_id=t.term_id;
update public.delegations d set from_school_id=b.from_school_id from private.backup_hazem_deleg_2026_11_06 b where b.id=d.id;
