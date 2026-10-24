-- استرجاع عودة آمال محمد محمود احمد وهبه مصطفى محمد جاد الرب من الإجازة (2026-10-24)
-- يعيد: حالة الإجازتين «مجددة» كما كانت، والفصول السبعة لمعلمات الأجر كما كانت.
begin;
update teacher_long_leaves set renewal_status='renewed', decision_number='مؤقت — بانتظار رقم القرار', decision_date='2026-10-22'
 where id in ('044a4747-4d7b-499c-826e-07c0e737c5fd','f1cadf25-8d8f-4f65-94f5-28def09437c1');
-- التحرير حراجية بنين 1/1، 1/2 ← جهاد عبد الناصر محمد سعيد
update teaching_assignments set teacher_id='b26e10cb-025b-4f4a-be74-a60ac00cb725' where id in ('c1f20355-a6f0-45d3-9d80-8593f6cf4bfe','b88d7b3a-ba62-41c9-804e-31ead3024d0e');
-- خزام الجديدة 2/1، 2/2 ← هدير يوسف احمد محمد
update teaching_assignments set teacher_id='ec561d64-fffd-472b-a476-560fa0006232' where id in ('385a3580-515e-4dbf-8019-6a0a57b829d7','bdb1f718-0538-491f-a1ce-e526dfb5d9cb');
-- خزام الجديدة 2/3، 2/4، 2/5 ← اسراء رزيقي جاد الكريم عبدالرحيم
update teaching_assignments set teacher_id='ab3028b3-3a8c-47d1-a5bd-4b1ff41ea0a5' where id in ('0b7314b8-46fe-4308-8d43-2ed8e7aab3fd','2b5636ca-a6a1-4998-8b9a-0d379766085f','8b8abe6b-1cd7-4690-88be-7a27d5ff1612');
commit;
