-- استرجاع v421: إزالة جدول الإجازات القصيرة ودواله (يُشغَّل من SQL Editor)
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- تنبيه: يمحو أي إجازات قصيرة مسجلة.
drop function if exists public.teacher_short_leave_balance(uuid, date);
drop table if exists public.teacher_short_leaves;
drop function if exists private.v421_guard();
drop function if exists private.v421_annual_limit(text);
drop function if exists private.v421_year_start(text, date);
drop function if exists private.v421_workdays(date, date);
-- المتوقع: Success. No rows returned
