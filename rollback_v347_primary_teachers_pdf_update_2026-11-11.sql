-- استرجاع v347: إعادة الهاتف وتاريخ التعيين والمؤهل وسنته لـ57 معلمًا ابتدائيًا كما كانت قبل تحديث ملف الموجه (2026-11-11).
-- يعتمد على private.v347_backup_teacher_records (لا تحذفه).
-- مشغّل مشرف المادة التلقائي يُوقف أثناء الاسترجاع حتى لا يتغير الإشراف.
-- النتيجة المتوقعة عند النجاح: UPDATE 57
begin;
alter table public.teacher_records disable trigger teacher_records_auto_senior_teacher;
update public.teacher_records t
   set phone=b.phone, appointment_date=b.appointment_date,
       qualification=b.qualification, qualification_year=b.qualification_year
  from private.v347_backup_teacher_records b
 where b.id=t.id;
alter table public.teacher_records enable trigger teacher_records_auto_senior_teacher;
insert into public.audit_log(action, entity_type, new_data)
values ('v347_primary_teachers_pdf_update_rollback','teacher_records', jsonb_build_object('restored_from','private.v347_backup_teacher_records'));
commit;
