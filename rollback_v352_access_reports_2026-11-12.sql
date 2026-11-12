-- استرجاع v352_access_reports: يعيد presence_ping و tp_check لنصيهما السابقين ويزيل سجل الدخول والمحاولات والتقريرين.
-- يمحو سجلات الدخول والمحاولات المحفوظة منذ التطبيق. لا يمس أي بيانات تعليمية.
-- يعتمد على private.v352_backup_functions (لا يُحذف قبل التشغيل).
-- يُشغَّل في SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- المتوقع عند النجاح: Success. No rows returned
do $do$
declare r record;
begin
  for r in select def from private.v352_backup_functions loop
    execute r.def;
  end loop;
end
$do$;
drop function if exists public.admin_access_report(timestamptz, timestamptz);
drop function if exists public.admin_denied_attempts(timestamptz, timestamptz);
drop function if exists public.log_login_failure(text, text);
drop function if exists private.v352_device();
drop index if exists public.teacher_portal_attempts_created_idx;
drop table if exists public.login_failures;
drop table if exists public.user_access_log;
