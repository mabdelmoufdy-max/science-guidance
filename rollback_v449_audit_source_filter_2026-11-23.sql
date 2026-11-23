-- استرجاع v449: إزالة دالتي التدقيق بالمصدر والدالة المساعدة. لا يمس audit_log ولا admin_audit_search2/admin_audit_actions.
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- الواجهة تعود تلقائيًا للدالتين القديمتين (تختفي قائمة «المصدر»).
drop function if exists public.admin_audit_search3(timestamptz,timestamptz,uuid,text,text,uuid,bigint,integer,text);
drop function if exists public.admin_audit_actions2(timestamptz,timestamptz,text);
drop function if exists private.v449_audit_source(uuid,text,jsonb);
-- المتوقع: Success. No rows returned
