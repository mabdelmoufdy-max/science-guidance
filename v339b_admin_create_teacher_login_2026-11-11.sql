-- v339b (2026-11-11): مدير النظام ينشئ حساب دخول لمعلم موجود من صفحة «تعديل بيانات المعلم» (المرحلة 3).
-- تعديل نصي واحد في service_link_created_system_user_atomic: يُضاف 'senior_teacher','teacher' لقائمة ما ينشئه admin.
-- (بقية الفحوص بلا تغيير؛ الموجه ومشرف المادة كما هما.) تُستدعى من دالة الحافة create-system-user v12.
-- الاسترجاع: rollback_v339b_admin_create_teacher_login_2026-11-11.sql (يعتمد على private.v339_backup_functions).
insert into private.v339_backup_functions(name, def)
select 'public.service_link_created_system_user_atomic', pg_get_functiondef('public.service_link_created_system_user_atomic'::regproc)
on conflict (name) do nothing;

do $m$
declare v_def text; v_old text := $o$v_allowed := (p_actor_role='admin' and p_role in ('first_supervisor','stage_coordinator','supervisor','school_manager'))$o$;
begin
  select pg_get_functiondef('public.service_link_created_system_user_atomic'::regproc) into v_def;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then raise exception 'v339b: النص غير مطابق'; end if;
  execute replace(v_def, v_old, $n$v_allowed := (p_actor_role='admin' and p_role in ('first_supervisor','stage_coordinator','supervisor','school_manager','senior_teacher','teacher'))$n$);
end
$m$;
