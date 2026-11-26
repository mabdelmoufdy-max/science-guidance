-- تحقق من اكتمال الاستعادة بالأعداد (قراءة فقط، بلا بيانات). يُشغَّل مرتين ويُقارن الناتجان سطرًا بسطر:
--   (1) على الإنتاج — للقراءة فقط، بواسطة مالك المشروع من SQL Editor أو psql.
--   (2) على قاعدة الاختبار بعد الاستعادة.
-- المتوقع: كل الأسطر متطابقة. أي فرق = استعادة ناقصة (غالبًا دور ناقص فلم تُطبَّق GRANTs أو الملكية).
begin read only;
select 'tables_public_private='||count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind in ('r','p')
union all select 'views_public='||count(*) from pg_class c where c.relnamespace='public'::regnamespace and c.relkind in ('v','m')
union all select 'functions_public_private='||count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private')
union all select 'policies_public_storage='||count(*) from pg_policies where schemaname in ('public','storage')
union all select 'table_grants_public='||count(*) from information_schema.role_table_grants where table_schema='public'
union all select 'routine_grants_public='||count(*) from information_schema.routine_privileges where routine_schema='public'
union all select 'rls_enabled_public='||count(*) from pg_class c where c.relnamespace='public'::regnamespace and c.relkind='r' and c.relrowsecurity
union all select 'owner_teacher_workload_summary='||pg_get_userbyid(relowner) from pg_class where oid='public.teacher_workload_summary'::regclass
union all select 'owner_teacher_official_staffing='||pg_get_userbyid(relowner) from pg_class where oid='public.teacher_official_staffing'::regclass
union all select 'owner_school_supervisor_choice='||pg_get_userbyid(relowner) from pg_class where oid='public.school_supervisor_choice'::regclass
union all select 'owner_audit_log='||pg_get_userbyid(relowner) from pg_class where oid='public.audit_log'::regclass
union all select 'owner_lookup_identity_by_civil='||pg_get_userbyid(proowner) from pg_proc where oid='public.lookup_identity_by_civil(text)'::regprocedure
union all select 'grants_4_objects='||md5(coalesce((select string_agg(grantee||':'||privilege_type||':'||table_name,',' order by grantee||':'||privilege_type||':'||table_name)
   from information_schema.role_table_grants where table_schema='public' and table_name in ('teacher_workload_summary','teacher_official_staffing','school_supervisor_choice','audit_log')),'')
   ||coalesce((select string_agg(grantee||':'||privilege_type,',' order by grantee||':'||privilege_type) from information_schema.routine_privileges where routine_schema='public' and routine_name='lookup_identity_by_civil'),''))
union all select 'defs_4_objects='||md5(pg_get_viewdef('public.teacher_workload_summary'::regclass)||pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure)
   ||(select string_agg(coalesce(qual,'')||'|'||coalesce(with_check,''),',' order by policyname) from pg_policies where (tablename,policyname) in (('school_supervisor_choice','ssc_read'),('audit_log','audit_insert'))));
rollback;
