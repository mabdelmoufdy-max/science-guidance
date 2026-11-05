-- استرجاع v280 — شغّله في: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يلغي صلاحية الموجه في الحذف فقط؛ لا يعيد فصولًا حُذفت (بياناتها محفوظة في audit_log.old_data بالإجراء supervisor_remove_class).
drop function if exists public.supervisor_remove_class(uuid);
-- المتوقع: Success. No rows returned
