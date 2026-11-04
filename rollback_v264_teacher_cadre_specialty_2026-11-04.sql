-- استرجاع v264: «التخصص على الكادر»
-- الخطوة 1 (اختيارية، انتقائية): تفريغ القيم التي عُبّئت آليًا فقط وإبقاء ما أدخله المستخدمون بعدها.
-- يحتاج تعطيل مشغلات التحديث مؤقتًا حتى لا يتغير updated_at/row_version.
alter table public.teacher_records disable trigger trg_teacher_records_updated_at;
alter table public.teacher_records disable trigger trg_teacher_records_row_version;
alter table public.teacher_records disable trigger trg_audit_teacher_record_changes;
update public.teacher_records tr set cadre_specialty = null
  from private.v264_backup_prefill b where b.teacher_id = tr.id and tr.cadre_specialty = b.value;
alter table public.teacher_records enable trigger trg_teacher_records_updated_at;
alter table public.teacher_records enable trigger trg_teacher_records_row_version;
alter table public.teacher_records enable trigger trg_audit_teacher_record_changes;

-- الخطوة 2 (إزالة الحقل كاملًا؛ يفقد أي قيم أُدخلت يدويًا): نفّذها فقط إذا أردت إلغاء الحقل نهائيًا.
-- alter table public.teacher_records drop column cadre_specialty;   -- يحذف القيد معه
-- ملاحظة: جدول private.v264_backup_prefill يُترك (لا يُحذف).
