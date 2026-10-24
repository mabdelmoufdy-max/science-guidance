-- Rollback (2026-10-24): شيماء اشرف عابدين (بالأجر، أصلية مصنع السكر ع) — نُقل انتدابها الجزئي وفصولها من الابتدائية «جزيرة مطيرة ت. س الجديدة» (4/1، 5/1، 6/1 = 9) إلى الإعدادية «جزيرة مطيرة تعليم اساسي اعدادي الجديدة» (1/1، 2/1، 3/1 = 12)
begin;
update public.teaching_assignments ta set class_id=v.c::uuid, subject_id=v.s::uuid, weekly_periods=3 from (values
 ('2870d8a0-7142-488d-b021-0b2bfa06300f', (select id::text from public.school_classes where school_id='e080dbda-6659-4711-b8e2-50f3e455de84' and class_name='4/1'), null),
 ('0c8a7e46-140f-4fc1-a2de-b70f7bbefbaf', (select id::text from public.school_classes where school_id='e080dbda-6659-4711-b8e2-50f3e455de84' and class_name='5/1'), null),
 ('76afc539-cd5b-4011-a7a6-d9e35912a625', (select id::text from public.school_classes where school_id='e080dbda-6659-4711-b8e2-50f3e455de84' and class_name='6/1'), null)) v(id,c,s)
 where ta.id=v.id::uuid;
-- subject_id: يُعاد من متطلبات الفصل الابتدائي
update public.teaching_assignments ta set subject_id=r.subject_id from public.class_subject_requirements r where r.class_id=ta.class_id and ta.id in ('2870d8a0-7142-488d-b021-0b2bfa06300f','0c8a7e46-140f-4fc1-a2de-b70f7bbefbaf','76afc539-cd5b-4011-a7a6-d9e35912a625');
update public.delegations set to_school_id='e080dbda-6659-4711-b8e2-50f3e455de84' where id='f943e6bc-2e33-4d9b-baa0-3b34efc9593b';
update public.teacher_school_assignments set school_id='e080dbda-6659-4711-b8e2-50f3e455de84' where id='49d47cdb-d699-4e1f-99db-99aadb770534';
commit;
