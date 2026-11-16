-- v390: إدخال بيانات المدارس للموجه (بقرار المستخدم 2026-11-16: «نفذ التوصية» 1أ+2أ+3أ)
-- الموجه يعدّل مدارسه المباشرة (schools.supervisor_id = سجله: ابتدائي/إعدادي) كالمنسق، دون أن يوسّع نطاقه:
--   * الفصول (school_classes): إدراج/تعديل/حذف لمدرسته المباشرة.
--   * إسناد الفصول (teaching_assignments): إدراج لمدرسته المباشرة (الحذف موجود: teaching_sup_remove).
--   * بيانات المدرسة الأساسية (schools): نوع/بنين-بنات/هاتف/عنوان/عدد الفصول فقط — مشغّل يمنع تغيير الموجه/المرحلة/الاسم/المدير/الاعتماد.
-- موجه المادة في الثانوي (supervisor_school_subjects) لا يدخل هنا: عرض واعتماد فقط كما كان.
-- الدور النشط = supervisor (ترويسة x-app-role عبر current_app_role). لا مساس بسياسات المنسق ولا بمصفوفة الصلاحيات (مشغلاتها تسري تلقائيًا).

create or replace function private.v390_direct_school(p_school uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select private.current_app_role() = 'supervisor'
     and exists (
       select 1 from public.schools s
       where s.id = p_school
         and s.supervisor_id is not null
         and s.supervisor_id = private.current_supervisor_id()
     )
$$;
revoke all on function private.v390_direct_school(uuid) from public, anon;
grant execute on function private.v390_direct_school(uuid) to authenticated;

create policy classes_sup_insert on public.school_classes
  for insert
  with check (private.v390_direct_school(school_id));

create policy classes_sup_update on public.school_classes
  for update
  using (private.v390_direct_school(school_id))
  with check (private.v390_direct_school(school_id));

create policy classes_sup_remove on public.school_classes
  for delete
  using (private.v390_direct_school(school_id) and not private.class_has_assignments(id));

create policy teaching_sup_insert on public.teaching_assignments
  for insert
  with check (
    private.current_app_role() = 'supervisor'
    and exists (
      select 1 from public.school_classes c
      where c.id = teaching_assignments.class_id
        and private.v390_direct_school(c.school_id)
    )
  );

create policy schools_sup_update on public.schools
  for update
  using (private.v390_direct_school(id))
  with check (private.v390_direct_school(id));

create or replace function public.v390_supervisor_school_guard()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is not null and public.current_app_role() = 'supervisor' then
    if new.supervisor_id is distinct from old.supervisor_id
       or new.manager_profile_id is distinct from old.manager_profile_id
       or new.approval_authority is distinct from old.approval_authority
       or new.status is distinct from old.status
       or new.aggregate_with_school_id is distinct from old.aggregate_with_school_id
       or new.name is distinct from old.name
       or new.stage is distinct from old.stage then
      raise exception 'الموجه يعدّل بيانات المدرسة الأساسية فقط (النوع، بنين/بنات، الهاتف، العنوان، عدد الفصول)';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_v390_supervisor_school_guard
  before update on public.schools
  for each row execute function public.v390_supervisor_school_guard();

-- v390c: قراءة صفية لمعلمي مدارس الموجه (مطبّقة بعد اكتشاف التجربة الجافة أن إدراج معلم بـRETURNING يفشل للموجه
-- لأن teacher_records_read تعتمد قائمة محسوبة قبل الإدراج، فلا يرى الصف الجديد). المجموعة المرئية لا تتسع:
-- مدارس الموجه ⊂ ما تراه teacher_records_read أصلًا (تحقق لكل الموجهين: 0 فروق). نفس نمط teacher_records_coord_read للمنسق.
create policy teacher_records_sup_read on public.teacher_records
  for select
  using (
    (select private.current_app_role()) = 'supervisor'
    and home_school_id in (select unnest(private.accessible_school_ids()))
  );
