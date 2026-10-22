-- حذف 16 فصلًا زائدًا بلا إسناد (مطابقة لكشف الإعدادي) — 2026-10-22
-- يُشغَّل في Supabase → SQL Editor. لا يحذف أي فصل عليه إسناد أو حصص جدول أو رائد.
-- الاسترجاع: rollback_class_counts_2026-10-22.sql
begin;
delete from public.school_classes where id in (
 'd7ffc049-2b64-4b20-8067-9a22f298387c','2062a41d-0a50-43a9-a023-4e74d189820a','7dc1ae0a-4dda-4d72-93ab-ef1c13dd3e82',
 'a781df89-cdff-4ed6-a3a3-408ae278d31e','dd95f71b-58f2-4b34-b637-cd370c7d79ec','486bd0be-c242-45b0-8fd2-365f9e22e882',
 '8d4768f4-4f8e-4828-a019-ef3ffdf32c40','1245fb9a-2e8e-4800-b5bb-9b27de954a24','c221eeac-a36b-4cbb-b236-83d7362c9d7d',
 'f1a9abe7-11ca-4659-82cf-2f250a883a40','b1df3c2b-b770-4a1f-839b-8465c484e6e2','9daaca02-dbd6-4af6-b29e-a31b5998573f',
 '7e3c9e34-96f0-4cbe-a421-166174fd9694','b79a1dd1-123f-48cc-868d-ba3999ef8c02','c0bbe24c-8373-47f7-b700-697c1877102d',
 'ff1fd877-e7b6-47ba-8e44-933e64c4f3a2')
 and not exists (select 1 from public.teaching_assignments a where a.class_id = school_classes.id)
 and not exists (select 1 from public.teacher_timetable_slots t where t.class_id = school_classes.id)
 and leader_teacher_id is null;
update public.schools s set class_count = (select count(*) from public.school_classes c
  where c.school_id = s.id and c.term_id = 'c1db173e-d123-4b00-84c3-301f3c4e6072')
 where s.name in ('قوص ع بنات','البهاء زهير ع','د / عبدالعزيز القوصي','المخزن الاعدادية','الشهيد شحات',
                  'العليقات الاعدادية','العبور حجازة','كوبري حجازة','عمر بن عبدالعزيز');
commit;
-- للتحقق بعد التشغيل:
select s.name, s.class_count from public.schools s
 where s.name in ('قوص ع بنات','البهاء زهير ع','د / عبدالعزيز القوصي','المخزن الاعدادية','الشهيد شحات',
                  'العليقات الاعدادية','العبور حجازة','كوبري حجازة','عمر بن عبدالعزيز') order by s.name;
