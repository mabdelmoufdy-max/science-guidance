-- استرجاع v385: إزالة حفظ «تجاهل المكررين» المشترك (يعود الواجهة للحفظ على الجهاز إن أُعيد نشر v383/v384).
drop function if exists public.dup_ignore_list();
drop function if exists public.dup_ignore_add(text);
drop function if exists public.dup_ignore_clear();
drop function if exists private.v385_check_role();
drop table if exists public.teacher_dup_ignored;
