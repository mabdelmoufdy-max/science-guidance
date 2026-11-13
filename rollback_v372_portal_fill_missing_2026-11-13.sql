-- استرجاع v372: حذف الدالتين والعمود (البيانات التي أكملها المعلمون تبقى؛ تُعرف من audit_log action=teacher_portal_fill_missing).
drop function if exists public.teacher_portal_fill_missing(text,text,jsonb);
drop function if exists public.teacher_portal_contacts(text,text);
alter table public.teacher_portal_settings drop column if exists fill_open;
