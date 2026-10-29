insert into public.school_classes select * from public.bak_deleted_classes_industrial_2026_10_28 on conflict (id) do nothing;
insert into public.class_subject_requirements select * from public.bak_deleted_reqs_industrial_2026_10_28 on conflict do nothing;
