-- حذف السجل المكرر لـ«زينب ابوالحجاج علي حماده» (السكر ث بنات): السجل الثاني 29705012701769 (بلا إسناد ولا مراجع) — بطلب المستخدم 2026-10-28
-- السجل المُبقى: 27905012701769 (3 إسنادات). شغّله من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
create table if not exists public.bak_deleted_teacher_2026_10_28 as
  select * from public.teacher_records where id='8e08bc79-8407-4480-96dc-593dbd98ef6a';

delete from public.teacher_records t
 where t.id='8e08bc79-8407-4480-96dc-593dbd98ef6a'
   and t.civil_id='29705012701769'
   and not exists (select 1 from public.teaching_assignments a where a.teacher_id=t.id)
returning t.id, t.full_name, t.civil_id;
