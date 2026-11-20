-- استرجاع v425: يحذف دالتي الاعتماد فقط (الإجازات المعتمدة والإسنادات الملغاة تبقى؛ الإسنادات الملغاة محفوظة في audit_log action=long_leave_request_approved).
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new — عند النجاح: «Success. No rows returned».
drop function if exists public.long_leave_request_review(uuid, text, text, text, date);
drop function if exists public.long_leave_requests_pending();
