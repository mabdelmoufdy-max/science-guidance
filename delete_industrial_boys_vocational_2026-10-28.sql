-- قوص الصناعية بنين (بطلب المستخدم 2026-10-28): أولى عام 18 (أُضيفت المجموعتان 17 و18)، وأولى مهني 6 ← حذف المجموعتين 7 و8 (بلا إسناد)
-- شغّله من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
create table if not exists public.bak_deleted_classes_industrial_2026_10_28 as
  select * from public.school_classes where id in ('7fd35b7d-86d1-4545-a153-78a76c7c479d','3a839965-1dae-49f2-ab37-2ba17cb7a98d');
create table if not exists public.bak_deleted_reqs_industrial_2026_10_28 as
  select * from public.class_subject_requirements where class_id in ('7fd35b7d-86d1-4545-a153-78a76c7c479d','3a839965-1dae-49f2-ab37-2ba17cb7a98d');

delete from public.school_classes c
 where c.id in ('7fd35b7d-86d1-4545-a153-78a76c7c479d','3a839965-1dae-49f2-ab37-2ba17cb7a98d')
   and c.class_name in ('مهني — مجموعة 7','مهني — مجموعة 8')
   and not exists (select 1 from public.teaching_assignments a where a.class_id=c.id)
returning c.id, c.class_name;
