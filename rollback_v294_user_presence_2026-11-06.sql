-- استرجاع v294_user_presence: يزيل جدول نبضة الاتصال والدالتين فقط (لا بيانات أخرى تتأثر).
-- يُشغَّل في SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- المتوقع عند النجاح: Success. No rows returned
drop function if exists public.admin_online_users();
drop function if exists public.presence_ping();
drop table if exists public.user_presence;
