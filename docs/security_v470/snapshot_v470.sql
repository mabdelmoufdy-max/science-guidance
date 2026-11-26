-- بصمات للمقارنة (md5 فقط، بلا بيانات): تعريفات الكائنات الأربعة + صفوف العرضين واستجابة lookup لكل دور مصرّح له.
-- لقاعدة الاختبار فقط. الناتج سطر لكل بند «key=md5».
\set ON_ERROR_STOP 1
\if :{?keep_verbosity}
\else
\set VERBOSITY sqlstate
\endif
\pset tuples_only on
\pset format unaligned
begin;
\ir fixtures_v470.inc.sql
select 'def_view='||md5(pg_get_viewdef('public.teacher_workload_summary'::regclass));
select 'def_func='||md5(pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure));
select 'def_pol_'||policyname||'='||md5(coalesce(qual,'')||'|'||coalesce(with_check,'')) from pg_policies
 where (tablename,policyname) in (('school_supervisor_choice','ssc_read'),('audit_log','audit_insert')) order by policyname;
select 'owner_'||k||'='||o from (values
  ('view',(select pg_get_userbyid(relowner) from pg_class where oid='public.teacher_workload_summary'::regclass)),
  ('func',(select pg_get_userbyid(proowner) from pg_proc where oid='public.lookup_identity_by_civil(text)'::regprocedure))) v(k,o);
select 'grants='||md5(coalesce((select string_agg(grantee||':'||privilege_type||':'||table_name,',' order by grantee||':'||privilege_type||':'||table_name)
  from information_schema.role_table_grants where table_schema='public' and table_name in ('teacher_workload_summary','teacher_official_staffing','school_supervisor_choice','audit_log')),'')
  ||coalesce((select string_agg(grantee||':'||privilege_type,',' order by grantee||':'||privilege_type) from information_schema.routine_privileges where routine_schema='public' and routine_name='lookup_identity_by_civil'),''));
set local role authenticated;
select 'rows_'||r||'='||md5(coalesce((select string_agg(t::text, '|' order by t.teacher_id) from public.teacher_workload_summary t),''))
  ||' staffing='||md5(coalesce((select string_agg(t::text, '|' order by t.teacher_id) from public.teacher_official_staffing t),''))
  ||' ssc='||md5(coalesce((select string_agg(c::text, '|' order by c::text) from public.school_supervisor_choice c),''))
  ||' lookup='||md5(public.lookup_identity_by_civil('29001012199982')::text)
from (values ('00000000-0000-4000-a000-000000000004','admin'),('00000000-0000-4000-a000-000000000005','stage_coordinator'),
             ('00000000-0000-4000-a000-000000000006','supervisor'),('00000000-0000-4000-a000-000000000007','senior_teacher')) v(u,r)
  cross join lateral (select pg_temp.as_user(u, r)) s
order by r;
rollback;
