-- استرجاع v294c (إلغاء الإشراف في 11 مدرسة ابتدائية مع إبقاء مسؤول البيانات) — يعتمد على private.v294c_backup_*
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- عند النجاح: يعود مشرفو المدارس التسع كما كانوا بعد v294، وتُزال اختيارات «مسؤول البيانات» اليدوية للمدارس الـ11.
insert into public.school_supervisor_choice(school_id,grp,teacher_id,note,chosen_at,chosen_by)
select school_id,grp,teacher_id,note,chosen_at,chosen_by from private.v294c_backup_choice
on conflict (school_id,grp) do update set teacher_id=excluded.teacher_id, note=excluded.note, chosen_at=excluded.chosen_at, chosen_by=excluded.chosen_by;
delete from public.school_data_officer o
 where o.school_id in (select school_id from private.v294c_backup_targets)
   and not exists (select 1 from private.v294c_backup_officer b where b.school_id=o.school_id);
select private.sync_school_senior_teacher(school_id) from private.v294c_backup_targets;
