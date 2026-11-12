-- استرجاع v362 (توسيع المنسق + التجميد والجدولة + الملخص الأسبوعي)
-- قبله: أعد نشر دالتي الحافة السابقتين edge/create-system-user.v13.ts و edge/admin-reset-user-password.v5.ts
-- 1) إيقاف المهام المجدولة
select cron.unschedule('v362-scheduled-flags');
select cron.unschedule('v362-admin-digest');
-- 2) إعادة الدوال الخمس كما كانت قبل v362 (cap_allowed، cap_allowed_for، my_capabilities، admin_permission_matrix، service_link_created_system_user_atomic)
do $r$ declare d text; begin for d in select def from private.v362_backup_functions loop execute d; end loop; end $r$;
-- 3) حذف الدوال الجديدة
drop function if exists public.service_coord_account_check(uuid,uuid);
drop function if exists public.admin_flag_schedule_add(text,boolean,timestamptz,text);
drop function if exists public.admin_flag_schedule_cancel(uuid,text);
drop function if exists public.admin_freeze_add(timestamptz,timestamptz,text[],text[],text);
drop function if exists public.admin_freeze_cancel(uuid,text);
drop function if exists public.admin_schedule_list();
drop function if exists public.admin_digest_latest();
drop function if exists public.admin_digest_seen(bigint);
drop function if exists public.admin_digest_run();
drop function if exists private.run_scheduled_flags();
drop function if exists private.make_admin_digest();
-- 4) إجراء التوسيع ونوع الإجراء
delete from public.permission_grants where capability = 'widen.coord_accounts';
delete from public.permission_rules where capability = 'widen.coord_accounts';
delete from public.permission_capabilities where code = 'widen.coord_accounts';
alter table public.permission_capabilities drop constraint if exists permission_capabilities_kind_chk;
alter table public.permission_capabilities drop column if exists kind;
-- الجداول permission_freezes و scheduled_flag_changes و admin_digests تُترك سجلًا (بلا أثر بعد الخطوات السابقة)، وpg_cron يبقى مفعّلًا.
-- المتوقع عند النجاح: Success. No rows returned (أو صفّان true من cron.unschedule).
