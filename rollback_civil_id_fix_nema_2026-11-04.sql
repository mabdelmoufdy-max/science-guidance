-- استرجاع تصحيح الرقم القومي (2026-11-04): يعيد الرقم الخطأ القديم لنعمة سعيد محمد خلف هللا (الشهيد مجدي).
-- يلزم تعطيل حارس عدم تغيير الرقم المدني مؤقتًا ثم إعادته.
alter table public.teacher_records disable trigger trg_teacher_civil_id_immutable;
update public.teacher_records set civil_id='28707012703007'
 where id='c836634f-805b-47bd-9a0d-98d5eab63bf8' and civil_id='28706212703007';
alter table public.teacher_records enable trigger trg_teacher_civil_id_immutable;
-- المتوقع: UPDATE 1، وحالة المشغّل 'O' (مفعّل).
-- جدول المرجع المستورد (بلا مشغلات): يعيد الرقم القديم في سطر المرجع رقم 256.
update public.teacher_reference_2026 set civil_id='28707012703007' where id=256 and civil_id='28706212703007';
-- المتوقع: UPDATE 1.
