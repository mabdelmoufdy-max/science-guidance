-- استرجاع v402: يعيد بيانات سجل المعلم (اية مصطفى) من النسخة الاحتياطية دون لمس الإشراف.
alter table public.teacher_records disable trigger teacher_records_auto_senior_teacher;
alter table public.teacher_records disable trigger trg_teacher_supervision_priority;
update public.teacher_records t set full_name=b.full_name, job_title=b.job_title, residence=b.residence, qualification=b.qualification,
  qualification_type=b.qualification_type, qualification_issuer=b.qualification_issuer, qualification_grade=b.qualification_grade,
  qualification_date=b.qualification_date, religion=b.religion, nationality=b.nationality, marital_status=b.marital_status
from private.v402_backup_teacher_records b where b.id=t.id;
alter table public.teacher_records enable trigger teacher_records_auto_senior_teacher;
alter table public.teacher_records enable trigger trg_teacher_supervision_priority;
-- الأعمدة الجديدة (birth_date, birth_governorate, gender, employment_status, contract_group) تُترك فارغة القيم لهذا السجل بإعادتها null يدويًا إن لزم.
