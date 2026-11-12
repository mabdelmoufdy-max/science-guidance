-- استرجاع v360 (قاعدة البيانات). أعد أولًا نشر دوال الحافة السابقة من edge/:
--   execute-teacher-delegation.v4.ts، supervisor-save-and-approve.v4.ts، supervisor-create-class-and-approve.v2.ts، create-system-user.v12.ts
-- ثم شغّل:
drop function if exists public.my_capabilities();
drop function if exists public.service_cap_allowed(uuid,text,text);
drop function if exists private.cap_allowed_for(uuid,text,text);
update public.permission_rules set allowed = true where capability = 'account.create';  -- (حذف الإجراء نفسه اختياري؛ لا يُفحص بعد استرجاع دالة الحافة)
-- admin_control_center: الحقلان has_sup/has_teacher إضافة بلا أثر، تُترك أو تُزال بإعادة تشغيل v355_control_center_read_2026-11-12.sql
