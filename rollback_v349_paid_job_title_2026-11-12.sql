-- استرجاع v349: يلغي المشغّل ويعيد المسميات السابقة لمعلمي الأجر (يعتمد على private.v349_backup_paid_job_title — لا يُحذف)
drop trigger if exists trg_v349_paid_job_title on public.teacher_records;
drop function if exists private.v349_paid_job_title();
alter table public.teacher_records disable trigger trg_teacher_records_updated_at;
alter table public.teacher_records disable trigger trg_teacher_records_row_version;
alter table public.teacher_records disable trigger trg_audit_teacher_record_changes;
alter table public.teacher_records disable trigger teacher_records_auto_senior_teacher;
update public.teacher_records t set job_title=b.job_title from private.v349_backup_paid_job_title b where b.id=t.id and t.job_title='معلم بالأجر';
alter table public.teacher_records enable trigger trg_teacher_records_updated_at;
alter table public.teacher_records enable trigger trg_teacher_records_row_version;
alter table public.teacher_records enable trigger trg_audit_teacher_record_changes;
alter table public.teacher_records enable trigger teacher_records_auto_senior_teacher;
-- المتوقع: UPDATE 122 (101 فارغ + 16 «معلم» + 3 «معلم مساعد» + غير النشطين)
