-- استرجاع v419: إزالة منع إسناد المعلم المجاز (يُشغَّل من SQL Editor)
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
drop trigger if exists trg_v419_leave_assign_guard on public.teaching_assignments;
drop function if exists private.v419_leave_assign_guard();
-- المتوقع: Success. No rows returned
