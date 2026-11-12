-- استرجاع v361: يحذف دالتي القراءة الجديدتين؛ وتسجيل «ما يراه» كل مرة يعود بإعادة تشغيل جزء admin_view_as من v359_person_permission_toggle_2026-11-12.sql
drop function if exists public.admin_audit_search2(timestamptz,timestamptz,uuid,text,text,uuid,bigint,int);
drop function if exists public.admin_audit_actions(timestamptz,timestamptz);
