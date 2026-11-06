-- استرجاع تصحيح بيانات داليا حامد عبدالغني الجيار (2026-11-06) من النسخة الاحتياطية private.v281_backup_dalia
-- شغّله في: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
alter table public.teacher_records disable trigger trg_teacher_civil_id_immutable;
update public.teacher_records t set civil_id=b.civil_id, phone=b.phone, work_start_date=b.work_start_date,
  grade_acquired_date=b.grade_acquired_date, qualification=b.qualification, specialty=b.specialty,
  residence=b.residence, teacher_code=b.teacher_code
from private.v281_backup_dalia b where t.id=b.id;
alter table public.teacher_records enable trigger trg_teacher_civil_id_immutable;
update public.teacher_reference_2026 r set civil_id=b.civil_id from private.v281_backup_dalia_ref b where r.id=b.id;
-- المتوقع: UPDATE 1 مرتين، والرقم القومي يعود 27110190200829.
