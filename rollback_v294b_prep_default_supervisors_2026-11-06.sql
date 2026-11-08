-- استرجاع v294b (اختيار الأقدم مشرفًا في مدرستين إعداديتين) — يعتمد على private.v294b_backup_*
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- عند النجاح: تعود اختيارات «شاغر» كما كانت، وتُحذف الاختيارات التي لم تكن موجودة، ويُعاد حساب الإشراف للمدرستين فتعودان بلا مشرف.
-- تنبيه: أي تعديل أجراه الموجه على مشرف هذه المدارس بعد v294b سيُلغى.
delete from public.school_supervisor_choice c
 where c.school_id in (select school_id from private.v294b_backup_targets)
   and not exists (select 1 from private.v294b_backup_choice b where b.school_id=c.school_id and b.grp=c.grp);
insert into public.school_supervisor_choice(school_id,grp,teacher_id,note,chosen_at,chosen_by)
select school_id,grp,teacher_id,note,chosen_at,chosen_by from private.v294b_backup_choice
on conflict (school_id,grp) do update set teacher_id=excluded.teacher_id, note=excluded.note, chosen_at=excluded.chosen_at, chosen_by=excluded.chosen_by;
select private.sync_school_senior_teacher(school_id) from private.v294b_backup_targets;
