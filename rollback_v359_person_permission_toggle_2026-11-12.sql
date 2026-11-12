-- استرجاع v359: إلغاء الاستثناءات الدائمة ثم إعادة الدوال كما في v358
-- 1) ألغِ الاستثناءات الدائمة السارية (لا حذف):
update public.permission_grants set revoked_at = now() where expires_at is null and revoked_at is null;
-- 2) أعد تشغيل أجزاء cap_allowed وadmin_grant_add وadmin_grants_list وadmin_view_as من v358_control_center_governance_2026-11-12.sql
-- 3) عمود expires_at يبقى يقبل الفراغ (لا ضرر بعد إلغاء الدائمة)؛ لإعادته: alter table public.permission_grants alter column expires_at set not null;
--    (يفشل إن بقي سطر بلا تاريخ — حدّث أولًا: update public.permission_grants set expires_at = coalesce(revoked_at, now()) + interval '1 second' where expires_at is null;)
