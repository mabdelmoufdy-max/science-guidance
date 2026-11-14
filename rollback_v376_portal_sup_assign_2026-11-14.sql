-- استرجاع v376: يحذف الدوال الجديدة والمفتاح فقط (لا يمس أي إسناد قائم؛ ما أُسند/أُلغي عبرها يُسترجع من audit_log: teacher_portal_sup_assign / teacher_portal_sup_unassign).
drop function if exists public.teacher_portal_assign_board(text, text, uuid);
drop function if exists public.teacher_portal_sup_assign(text, text, uuid, uuid, uuid, uuid);
drop function if exists public.teacher_portal_sup_unassign(text, text, uuid, uuid);
drop function if exists private.v376_assignable(uuid, uuid);
alter table public.teacher_portal_settings drop column if exists assign_open;
