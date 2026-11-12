-- v357 مركز التحكم — المرحلة 3: مصفوفة الصلاحيات (إيقاف إجراء لدور بعينه، مفروض في قاعدة البيانات)
-- الافتراضي: كل الخلايا «مسموح كما هو الآن» فلا يتغير أي سلوك. «ممنوع» يضيف منعًا فوق القواعد الحالية ولا يوسّع أي صلاحية.
-- مدير النظام لا يُمنع أبدًا. المشغلات المتداخلة (مزامنات النظام، pg_trigger_depth()>1) لا تُفحص.

create table if not exists public.permission_capabilities(
  code text primary key,
  label text not null,
  description text not null,
  sort int not null default 0
);
create table if not exists public.permission_rules(
  capability text not null references public.permission_capabilities(code) on update cascade,
  role public.app_role not null,
  allowed boolean not null default true,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  primary key (capability, role)
);
alter table public.permission_capabilities enable row level security;
alter table public.permission_rules enable row level security;
revoke all on public.permission_capabilities from anon, authenticated;
revoke all on public.permission_rules from anon, authenticated;

insert into public.permission_capabilities(code, label, description, sort) values
 ('teacher.add','إضافة معلم','إنشاء سجل معلم جديد',10),
 ('teacher.edit','تعديل بيانات معلم','أي تعديل في سجل المعلم (البيانات، الدرجة، الإشراف، المدرسة الأصلية)',20),
 ('teacher.civil_id','تغيير الرقم القومي','تغيير الرقم القومي للمعلم',30),
 ('teacher.school_link','ربط المعلم بالمدارس','نقل المعلم أو ربطه بمدرسة في الفصل الدراسي',40),
 ('delegation.manage','الانتداب وإلغاؤه','إنشاء انتداب أو تعديله أو إلغاؤه',50),
 ('classes.manage','الفصول والحصص المقررة','إضافة فصول أو مجموعات أو حذفها وتعديل حصص المواد',60),
 ('assignment.manage','إسناد الفصول','إسناد فصل لمعلم أو إلغاء الإسناد أو نقله',70),
 ('timetable.manage','الجداول المدرسية','إعداد جدول المدرسة وحصص المعلمين داخل البرنامج',80),
 ('approval.manage','الاعتماد والإرسال','إرسال المدرسة للاعتماد واعتمادها وإعادتها للتعديل',90),
 ('completion.submit','استكمال البيانات','إرسال قيم ناقصة أو معدّلة من شاشة استكمال البيانات',100),
 ('paid.manage','حصص الأجر','توزيع حصص العجز على معلمي الأجر',110),
 ('school.settings','إعدادات المدرسة','مسؤول البيانات وبيانات مدير المدرسة واختيار مشرف المادة',120)
on conflict (code) do update set label = excluded.label, description = excluded.description, sort = excluded.sort;

insert into public.permission_rules(capability, role, allowed)
select c.code, r.role, true
from public.permission_capabilities c
cross join (values ('stage_coordinator'::public.app_role),('supervisor'),('senior_teacher'),('school_manager'),('teacher'),('first_supervisor')) r(role)
on conflict do nothing;

create or replace function private.cap_allowed(p_cap text) returns boolean
language plpgsql stable security definer set search_path = public, pg_temp as $fn$
declare v_role public.app_role;
begin
  if auth.uid() is null then return true; end if;
  v_role := private.current_app_role();
  if v_role is null or v_role = 'admin' then return true; end if;
  return coalesce((select allowed from public.permission_rules where capability = p_cap and role = v_role), true);
end $fn$;
revoke all on function private.cap_allowed(text) from public, anon;
grant execute on function private.cap_allowed(text) to authenticated;

-- مشغل عام على مستوى الجملة: TG_ARGV = قائمة الصلاحيات المطلوبة
create or replace function private.v357_cap_gate() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $fn$
declare c text; v_label text;
begin
  if pg_trigger_depth() > 1 then return null; end if;
  foreach c in array TG_ARGV loop
    if not private.cap_allowed(c) then
      select label into v_label from public.permission_capabilities where code = c;
      raise exception 'هذا الإجراء موقوف لدورك من مركز التحكم: %', coalesce(v_label, c) using errcode = '42501';
    end if;
  end loop;
  return null;
end $fn$;

-- مشغل صفّي لتغيير الرقم القومي فقط
create or replace function private.v357_civil_gate() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $fn$
begin
  if pg_trigger_depth() > 1 then return new; end if;
  if not private.cap_allowed('teacher.civil_id') then
    raise exception 'هذا الإجراء موقوف لدورك من مركز التحكم: تغيير الرقم القومي' using errcode = '42501';
  end if;
  return new;
end $fn$;

create trigger trg_v357_cap_ins before insert on public.teacher_records for each statement execute function private.v357_cap_gate('teacher.add');
create trigger trg_v357_cap_upd before update on public.teacher_records for each statement execute function private.v357_cap_gate('teacher.edit');
create trigger trg_v357_civil before update of civil_id on public.teacher_records for each row when (old.civil_id is distinct from new.civil_id) execute function private.v357_civil_gate();
create trigger trg_v357_cap before insert or update or delete on public.teacher_school_assignments for each statement execute function private.v357_cap_gate('teacher.school_link');
create trigger trg_v357_cap before insert or update or delete on public.delegations for each statement execute function private.v357_cap_gate('delegation.manage');
create trigger trg_v357_cap before insert or update or delete on public.school_classes for each statement execute function private.v357_cap_gate('classes.manage');
create trigger trg_v357_cap before insert or update or delete on public.class_subject_requirements for each statement execute function private.v357_cap_gate('classes.manage');
create trigger trg_v357_cap before insert or update or delete on public.teaching_assignments for each statement execute function private.v357_cap_gate('assignment.manage');
create trigger trg_v357_cap before insert or update or delete on public.school_timetable_config for each statement execute function private.v357_cap_gate('timetable.manage');
create trigger trg_v357_cap before insert or update or delete on public.teacher_timetable_slots for each statement execute function private.v357_cap_gate('timetable.manage');
create trigger trg_v357_cap before insert or update or delete on public.school_submissions for each statement execute function private.v357_cap_gate('approval.manage');
create trigger trg_v357_cap before insert or update or delete on public.data_completion_changes for each statement execute function private.v357_cap_gate('completion.submit');
create trigger trg_v357_cap before insert or update or delete on public.teacher_paid_shortage_allocations for each statement execute function private.v357_cap_gate('paid.manage');
create trigger trg_v357_cap before insert or update or delete on public.school_data_officer for each statement execute function private.v357_cap_gate('school.settings');
create trigger trg_v357_cap before insert or update or delete on public.school_manager_contact for each statement execute function private.v357_cap_gate('school.settings');
create trigger trg_v357_cap before insert or update or delete on public.school_supervisor_choice for each statement execute function private.v357_cap_gate('school.settings');

-- قراءة المصفوفة وتعديلها (مدير النظام فقط)
create or replace function public.admin_permission_matrix()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $fn$
begin
  perform private.v356_require_admin();
  return jsonb_build_object(
    'capabilities', (select coalesce(jsonb_agg(jsonb_build_object('code',code,'label',label,'description',description) order by sort), '[]'::jsonb) from public.permission_capabilities),
    'rules', (select coalesce(jsonb_agg(jsonb_build_object('cap',capability,'role',role::text,'allowed',allowed,'updated_at',updated_at)), '[]'::jsonb) from public.permission_rules),
    'accounts', (select coalesce(jsonb_object_agg(role, c), '{}'::jsonb) from (select ur.role::text role, count(*) c from public.user_roles ur join public.profiles p on p.id = ur.profile_id and p.is_active where ur.is_active group by ur.role) x));
end $fn$;

create or replace function public.admin_set_permissions(p_changes jsonb, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $fn$
declare v_actor uuid := private.v356_require_admin(); e jsonb; v_old boolean; v_n int := 0; v_log jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_changes) <> 'array' then raise exception 'صيغة غير صحيحة'; end if;
  for e in select * from jsonb_array_elements(p_changes) loop
    if (e->>'role') = 'admin' then raise exception 'مدير النظام لا يُقيَّد'; end if;
    select allowed into v_old from public.permission_rules where capability = e->>'cap' and role = (e->>'role')::public.app_role;
    if not found then raise exception 'خلية غير معروفة: % / %', e->>'cap', e->>'role'; end if;
    if v_old is distinct from (e->>'allowed')::boolean then
      update public.permission_rules set allowed = (e->>'allowed')::boolean, updated_by = v_actor, updated_at = now()
      where capability = e->>'cap' and role = (e->>'role')::public.app_role;
      v_n := v_n + 1;
      v_log := v_log || jsonb_build_object('cap', e->>'cap', 'role', e->>'role', 'from', v_old, 'to', (e->>'allowed')::boolean);
    end if;
  end loop;
  if v_n > 0 then
    insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
    values (v_actor, 'admin', 'cc_permissions', 'permission_rules', null, null, jsonb_build_object('changes', v_log, 'reason', nullif(p_reason,'')));
  end if;
  return jsonb_build_object('ok', true, 'changed', v_n);
end $fn$;

revoke all on function public.admin_permission_matrix() from public, anon;
revoke all on function public.admin_set_permissions(jsonb,text) from public, anon;
grant execute on function public.admin_permission_matrix() to authenticated;
grant execute on function public.admin_set_permissions(jsonb,text) to authenticated;
