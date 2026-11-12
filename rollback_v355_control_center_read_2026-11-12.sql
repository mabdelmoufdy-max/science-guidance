-- استرجاع v355: يزيل دالتي القراءة فقط (لا بيانات)
drop function if exists public.admin_control_center();
drop function if exists public.admin_audit_search(timestamptz,timestamptz,uuid,text,int);
