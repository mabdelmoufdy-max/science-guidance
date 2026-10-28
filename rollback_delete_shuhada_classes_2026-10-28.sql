-- استرجاع الفصلين من النسخة الاحتياطية (بعد تشغيل delete_shuhada_classes_2026-10-28.sql)
insert into public.school_classes select * from public.bak_deleted_classes_2026_10_28 on conflict (id) do nothing;
insert into public.class_subject_requirements select * from public.bak_deleted_reqs_2026_10_28 on conflict do nothing;
