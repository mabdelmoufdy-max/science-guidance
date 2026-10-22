-- استرجاع تسجيل إجازات كشف الإعدادي (2026-10-22): هند سيد عبد المولى، هبه مصطفى محمد جاد الرب، امال محمد محمود احمد
begin;
delete from public.teacher_long_leaves
 where teacher_id in ('9ccd82ca-4cab-41ef-88ef-73081cb232e7','f189c3fe-8202-4b49-ac19-f4d41299ac45')
   and academic_year_id = '02bcee4c-4344-4756-8ce0-4252196a5a90'
   and notes like 'من كشف الإعدادي 2026-10-22%';
-- امال: كانت «إجازة طويلة» بانتظار التجديد بلا رقم/تاريخ قرار
update public.teacher_long_leaves set leave_type = 'إجازة طويلة', renewal_status = 'pending_renewal',
       decision_number = null, decision_date = null,
       notes = 'مرحل من مراجعة بيانات بداية العام؛ يحسب ماليًا حتى وصول قرار التجديد.'
 where id = '044a4747-4d7b-499c-826e-07c0e737c5fd';
commit;
