-- استرجاع السجل المحذوف من النسخة الاحتياطية
insert into public.teacher_records select * from public.bak_deleted_teacher_2026_10_28 on conflict (id) do nothing;
