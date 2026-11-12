-- استرجاع v356: يزيل دوال أفعال مركز التحكم (لا يعيد أثر الأفعال المنفذة؛ قيمها السابقة محفوظة في audit_log بالأفعال cc_*)
drop function if exists public.admin_account_action(uuid,text,text,text);
drop function if exists public.admin_move_schools(uuid[],uuid,boolean,text);
drop function if exists public.admin_set_flag(text,boolean,text);
drop function if exists private.v356_require_admin();
