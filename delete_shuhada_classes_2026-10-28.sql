-- حذف فصلين بلا إسناد في «الشهداء ث بنات» (بطلب المستخدم 2026-10-28):
--   الصف الثاني «ثانوية عامة — فصل 1» (638f7da2…) والصف الأول «علوم متكاملة — مجموعة 9» (688210b9…)
-- شغّله من SQL Editor. ينسخ الصفوف احتياطيًا أولًا، ولا يحذف فصلًا له إسناد.
create table if not exists public.bak_deleted_classes_2026_10_28 as
  select * from public.school_classes where id in ('688210b9-b76f-4df0-bff9-ed4e11c5309a','638f7da2-7ade-4e7d-adb4-f8d38d5ddb3d');
create table if not exists public.bak_deleted_reqs_2026_10_28 as
  select * from public.class_subject_requirements where class_id in ('688210b9-b76f-4df0-bff9-ed4e11c5309a','638f7da2-7ade-4e7d-adb4-f8d38d5ddb3d');

delete from public.school_classes c
 where c.id in ('688210b9-b76f-4df0-bff9-ed4e11c5309a','638f7da2-7ade-4e7d-adb4-f8d38d5ddb3d')
   and not exists (select 1 from public.teaching_assignments a where a.class_id=c.id)
returning c.id, c.class_name;
