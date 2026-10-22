-- استرجاع v155 (دور «المعلم» يرى سجله فقط) — يعيد can_access_teacher والعرض teacher_workload_summary كما كانا قبل 2026-10-22
-- مُختبر: يعيد التعريفين بالضبط (md5 ce5f12272f49382d306be783efc4eb92 و cf2ad904d9f641b5e7873f138ed947b8)
do $do$
declare v text; f text;
begin
 v := pg_get_viewdef('public.teacher_workload_summary'::regclass, true);
 v := regexp_replace(v, '\s+WHERE \(\( SELECT private\.current_app_role\(\) AS current_app_role\)\) IS DISTINCT FROM ''teacher''::app_role OR profile_id = \(\( SELECT auth\.uid\(\) AS uid\)\);$', ';');
 execute 'create or replace view public.teacher_workload_summary as '||v;
 f := pg_get_functiondef('private.can_access_teacher(uuid)'::regprocedure);
 f := replace(f, E'\n  -- المعلم (دور teacher) يرى سجله فقط ولا يرى بيانات زملائه\n  if r=''teacher'' then return false; end if;', '');
 execute f;
end $do$;
