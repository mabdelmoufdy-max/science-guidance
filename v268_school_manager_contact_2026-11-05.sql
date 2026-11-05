-- v268_school_manager_contact (2026-11-05)
-- اسم مدير المدرسة وهاتفه: جدول مستقل + دالة حفظ SECURITY DEFINER.
-- لا يغيّر schools ولا سياساتها ولا school_data_intake ولا manager_profile_id.
-- الكتابة: admin، منسق المرحلة لمدارس مرحلته، الموجه لمدارسه (supervises_school). القراءة: can_access_school.

create table public.school_manager_contact (
  school_id uuid primary key references public.schools(id),
  manager_name text check (manager_name is null or char_length(manager_name) <= 150),
  manager_phone text check (manager_phone is null or manager_phone ~ '^[0-9+ ]{6,20}$'),
  set_by uuid default auth.uid(),
  updated_at timestamptz not null default now()
);

alter table public.school_manager_contact enable row level security;

create policy smc_read on public.school_manager_contact
  for select to authenticated
  using (private.can_access_school(school_id));

revoke all on public.school_manager_contact from public, anon, authenticated;
grant select on public.school_manager_contact to authenticated;

create or replace function public.set_school_manager_contact(p_school_id uuid, p_name text, p_phone text)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare
  r public.app_role;
  v_stage text;
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_phone text := nullif(regexp_replace(translate(coalesce(p_phone, ''), '٠١٢٣٤٥٦٧٨٩', '0123456789'), '[^0-9+]', '', 'g'), '');
  v_old public.school_manager_contact%rowtype;
  v_new public.school_manager_contact%rowtype;
begin
  if auth.uid() is null then raise exception 'غير مصرح' using errcode = '42501'; end if;
  r := private.current_app_role();
  select s.stage into v_stage from public.schools s where s.id = p_school_id;
  if not found then raise exception 'المدرسة غير موجودة'; end if;

  if not (
    r = 'admin'
    or (r = 'stage_coordinator' and private.can_access_stage(v_stage))
    or (r = 'supervisor' and private.supervises_school(p_school_id, private.current_supervisor_id()))
  ) then
    raise exception 'لا تملك صلاحية تسجيل بيانات مدير هذه المدرسة' using errcode = '42501';
  end if;

  if v_phone is not null and v_phone !~ '^\+?[0-9]{6,15}$' then
    raise exception 'رقم الهاتف غير صحيح';
  end if;
  if v_name is not null and char_length(v_name) > 150 then
    raise exception 'الاسم أطول من المسموح';
  end if;

  select * into v_old from public.school_manager_contact where school_id = p_school_id;

  insert into public.school_manager_contact as c (school_id, manager_name, manager_phone, set_by, updated_at)
  values (p_school_id, v_name, v_phone, auth.uid(), now())
  on conflict (school_id) do update
    set manager_name = excluded.manager_name,
        manager_phone = excluded.manager_phone,
        set_by = excluded.set_by,
        updated_at = excluded.updated_at
  returning * into v_new;

  insert into public.audit_log (actor_profile_id, action, entity_type, entity_id, old_data, new_data)
  values (auth.uid(), 'set_school_manager_contact', 'school_manager_contact', p_school_id::text,
          case when v_old.school_id is null then null else jsonb_build_object('manager_name', v_old.manager_name, 'manager_phone', v_old.manager_phone) end,
          jsonb_build_object('manager_name', v_new.manager_name, 'manager_phone', v_new.manager_phone));

  return jsonb_build_object('school_id', v_new.school_id, 'manager_name', v_new.manager_name,
                            'manager_phone', v_new.manager_phone, 'updated_at', v_new.updated_at);
end
$fn$;

revoke all on function public.set_school_manager_contact(uuid, text, text) from public, anon;
grant execute on function public.set_school_manager_contact(uuid, text, text) to authenticated;
