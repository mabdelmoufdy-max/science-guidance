-- استرجاع دفعة مراجعة صحائف الأحوال (150 معلمًا): يعيد الأعمدة القديمة من النسخة private.v402_backup_teacher_records2 (لا تُحذف).
alter table public.teacher_records disable trigger teacher_records_auto_senior_teacher;
alter table public.teacher_records disable trigger trg_teacher_supervision_priority;
update public.teacher_records t set full_name=b.full_name, job_title=b.job_title, residence=b.residence, appointment_date=b.appointment_date,
 work_start_date=b.work_start_date, qualification=b.qualification, qualification_year=b.qualification_year, qualification_type=b.qualification_type,
 qualification_issuer=b.qualification_issuer, qualification_grade=b.qualification_grade, qualification_date=b.qualification_date,
 religion=b.religion, nationality=b.nationality, marital_status=b.marital_status
from private.v402_backup_teacher_records2 b where b.id=t.id;
alter table public.teacher_records enable trigger teacher_records_auto_senior_teacher;
alter table public.teacher_records enable trigger trg_teacher_supervision_priority;
-- الأعمدة الجديدة (notional_date, decision_*, subject_taught, birth_*, gender, employment_status, contract_group) تُفرَّغ يدويًا إن لزم.
