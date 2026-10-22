-- استرجاع تسجيل الإجازتين المرضيتين (2026-10-22): هبه احمد حماده صالح ويحيي نور محمد احمد
begin;
delete from public.teacher_long_leaves
 where teacher_id in ('979c1d27-45a0-443b-afe0-129a25ebb7da','1dd40e09-b29b-4b18-a2ee-a2cbe971d6c2')
   and leave_type = 'إجازة مرضية'
   and academic_year_id = '02bcee4c-4344-4756-8ce0-4252196a5a90';
-- إعادة مدرسة يحيي الأصلية إلى «د / عبدالعزيز القوصي»
update public.teacher_records set home_school_id = '787d8b12-5e4e-4d3b-a6c8-c1a453a14257'
 where id = '1dd40e09-b29b-4b18-a2ee-a2cbe971d6c2';
update public.teacher_school_assignments set school_id = '787d8b12-5e4e-4d3b-a6c8-c1a453a14257'
 where id = '31855213-c8c0-407b-b2c1-4446a43c7b9d';
commit;
