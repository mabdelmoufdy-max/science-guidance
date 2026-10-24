-- إلغاء إجازتي آمال محمد محمود احمد وهبه مصطفى محمد جاد الرب (عادتا للعمل 2026-10-24)
-- يُشغَّل من Supabase → SQL Editor. الاسترجاع: rollback_delete_leaves_amal_hiba_2026-10-24.sql
delete from teacher_long_leaves
 where id in ('044a4747-4d7b-499c-826e-07c0e737c5fd','f1cadf25-8d8f-4f65-94f5-28def09437c1')
returning id, leave_type;
