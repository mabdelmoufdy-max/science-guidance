-- استرجاع v390: إزالة صلاحيات الموجه على إدخال بيانات المدارس (لا يمس سياسات المنسق ولا teaching_sup_remove من v344)
-- لا توجد بيانات مُغيَّرة بالهجرة نفسها (سياسات ومشغّل ودالة مساعدة فقط)؛ ما كتبه الموجه من فصول/إسنادات يبقى بيانات عادية.
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- المتوقع عند النجاح: «Success. No rows returned».

drop policy if exists classes_sup_insert on public.school_classes;
drop policy if exists classes_sup_update on public.school_classes;
drop policy if exists classes_sup_remove on public.school_classes;
drop policy if exists teaching_sup_insert on public.teaching_assignments;
drop policy if exists schools_sup_update on public.schools;
drop policy if exists teacher_records_sup_read on public.teacher_records;
drop trigger if exists trg_v390_supervisor_school_guard on public.schools;
drop function if exists public.v390_supervisor_school_guard();
drop function if exists private.v390_direct_school(uuid);
