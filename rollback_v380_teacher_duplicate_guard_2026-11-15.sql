-- استرجاع v380: إزالة مشغّل منع تكرار المعلم وفحص صيغة الرقم القومي (لا يمس أي بيانات)
drop trigger if exists trg_v380_dup_guard on public.teacher_records;
drop function if exists private.v380_teacher_dup_guard();
drop function if exists private.v380_civil_ok(text);
drop function if exists private.v380_norm_name(text);
