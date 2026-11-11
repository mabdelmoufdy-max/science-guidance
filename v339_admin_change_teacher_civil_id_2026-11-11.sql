-- v339 (2026-11-11): تغيير الرقم القومي للمعلم من صفحة «تعديل بيانات المعلم» — لمدير النظام فقط.
-- بطلب المستخدم: «صلاحية تعديل جميع البيانات بما فيه الرقم القومي» (المرحلة 1 من 3).
-- 1) استثناء ضيّق في مشغل منع تغيير الرقم (enforce_civil_id_identity): يُسمح فقط داخل الدالة الجديدة
--    (app.v339_civil_change='on') وبالدور النشط admin. بقية الحالات مرفوضة كما هي.
-- 2) دالة admin_change_teacher_civil_id(teacher, new_civil): 14 رقمًا (تقبل الأرقام العربية)، غير مكرر في
--    المعلمين/الحسابات/الموجهين/بريد الدخول؛ تغيّر سجل المعلم + حسابه (profiles) + سطر الموجه المرتبط به إن وُجد
--    + بريد الدخول (الرقم@science-guidance.local) إن كان الدخول بالرقم القومي؛ وتسجّل في audit_log.
-- الاسترجاع: rollback_v339_admin_change_teacher_civil_id_2026-11-11.sql

create table if not exists private.v339_backup_functions(name text primary key, def text not null, saved_at timestamptz not null default now());
insert into private.v339_backup_functions(name, def)
select 'public.enforce_civil_id_identity', pg_get_functiondef('public.enforce_civil_id_identity'::regproc)
on conflict (name) do nothing;

do $m$
declare v_def text; v_new text;
begin
  select pg_get_functiondef('public.enforce_civil_id_identity'::regproc) into v_def;
  if (length(v_def) - length(replace(v_def, 'if new.civil_id is distinct from old.civil_id then', ''))) / length('if new.civil_id is distinct from old.civil_id then') <> 1 then
    raise exception 'v339: نص المشغل غير مطابق';
  end if;
  v_new := replace(v_def, 'if new.civil_id is distinct from old.civil_id then',
    'if new.civil_id is distinct from old.civil_id and not (coalesce(current_setting(''app.v339_civil_change'', true), '''') = ''on'' and private.current_app_role() = ''admin'') then');
  execute v_new;
end
$m$;

create or replace function public.admin_change_teacher_civil_id(p_teacher_id uuid, p_new_civil text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $f$
declare
  t public.teacher_records%rowtype;
  v_new text; v_old text; v_pid uuid; v_sup uuid;
  v_email_old text; v_email_new text; v_login boolean := false;
begin
  if auth.uid() is null then raise exception 'غير مصرح' using errcode = '42501'; end if;
  if private.current_app_role() is distinct from 'admin' then
    raise exception 'تغيير الرقم القومي متاح لمدير النظام فقط' using errcode = '42501';
  end if;
  v_new := translate(btrim(coalesce(p_new_civil, '')), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
  if v_new !~ '^\d{14}$' then raise exception 'الرقم القومي يجب أن يكون 14 رقمًا'; end if;

  select * into t from public.teacher_records where id = p_teacher_id for update;
  if not found then raise exception 'سجل المعلم غير موجود'; end if;
  v_old := t.civil_id;
  if v_new = v_old then
    return jsonb_build_object('changed', false, 'row_version', t.row_version, 'civil_id', v_old);
  end if;

  if exists (select 1 from public.teacher_records where civil_id = v_new and id <> t.id) then
    raise exception 'الرقم القومي % مسجل لمعلم آخر', v_new;
  end if;

  v_pid := t.profile_id;
  if v_pid is null then select id into v_pid from public.profiles where civil_id = v_old; end if;
  if exists (select 1 from public.profiles where civil_id = v_new and id is distinct from v_pid) then
    raise exception 'الرقم القومي % مستخدم لحساب دخول آخر', v_new;
  end if;

  select id into v_sup from public.supervisors
   where (v_pid is not null and profile_id = v_pid) or btrim(civil_id) = v_old
   order by (profile_id = v_pid) desc nulls last limit 1;
  if exists (select 1 from public.supervisors where btrim(civil_id) = v_new and id is distinct from v_sup) then
    raise exception 'الرقم القومي % مسجل لموجه آخر', v_new;
  end if;

  v_email_new := v_new || '@science-guidance.local';
  if exists (select 1 from auth.users where lower(email) = v_email_new and id is distinct from v_pid) then
    raise exception 'الرقم القومي % مستخدم لحساب دخول آخر', v_new;
  end if;

  perform set_config('app.v339_civil_change', 'on', true);
  update public.teacher_records set civil_id = v_new where id = t.id;
  if v_pid is not null then
    update public.profiles set civil_id = v_new where id = v_pid;
    select email into v_email_old from auth.users where id = v_pid;
    if lower(coalesce(v_email_old, '')) = lower(v_old || '@science-guidance.local') then
      update auth.users
         set email = v_email_new,
             raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('civil_id', v_new),
             updated_at = now()
       where id = v_pid;
      update auth.identities
         set identity_data = coalesce(identity_data, '{}'::jsonb) || jsonb_build_object('email', v_email_new),
             updated_at = now()
       where user_id = v_pid and provider = 'email';
      v_login := true;
    end if;
  end if;
  if v_sup is not null then update public.supervisors set civil_id = v_new where id = v_sup; end if;
  perform set_config('app.v339_civil_change', 'off', true);

  insert into public.audit_log(actor_profile_id, action, entity_type, entity_id, old_data, new_data, actor_role)
  values (auth.uid(), 'admin_change_teacher_civil_id', 'teacher_records', t.id::text,
          jsonb_build_object('civil_id', v_old, 'profile_id', v_pid, 'supervisor_id', v_sup, 'login_email', case when v_login then v_email_old end),
          jsonb_build_object('civil_id', v_new, 'login_email', case when v_login then v_email_new end),
          'admin');

  return jsonb_build_object('changed', true, 'civil_id', v_new, 'login_changed', v_login,
                            'row_version', (select row_version from public.teacher_records where id = t.id));
end
$f$;

revoke all on function public.admin_change_teacher_civil_id(uuid, text) from public, anon;
grant execute on function public.admin_change_teacher_civil_id(uuid, text) to authenticated;
