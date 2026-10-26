-- استرجاع v186 (مشرف مادة لكل تخصص) إلى ما قبل التعديل. يُشغَّل من Supabase ← SQL Editor مرة واحدة.
-- يعتمد على جداول النسخ الاحتياطي private.v186_backup_* التي أنشأتها الهجرة (لا تُحذف قبل التأكد).
-- ملاحظة: يعيد أعلام المشرفين واختياراتهم إلى لحظة ما قبل الهجرة، فيُلغي أي تعديل إشراف جرى بعدها.
-- تنبيه: إن أُسندت لهالة سيد أحمد فصول في العسكرية بعد الهجرة فألغِ إسنادها أولًا، لأن الاسترجاع يحذف سجل مدرستها الأصلية المضاف.
begin;

do $chk$ begin
  if to_regclass('private.v186_backup_defs') is null or to_regclass('private.v186_backup_flags') is null
     or to_regclass('private.v186_backup_choice') is null or to_regclass('private.v186_backup_rows') is null then
    raise exception 'rollback v186: جداول النسخ الاحتياطي غير موجودة';
  end if;
end $chk$;

-- 1) إيقاف المشغّلات الجديدة
drop trigger if exists trg_schools_sup_group on public.schools;
drop trigger if exists trg_teacher_records_sup_group on public.teacher_records;

-- 2) إعادة أعلام المشرفين كما كانت (دون إثارة المشغّلات؛ على مرحلتين لتجنب تعارض الفهرس مؤقتًا)
set local session_replication_role = replica;
update public.teacher_records t set is_senior_teacher = false
  from private.v186_backup_flags b
 where b.id = t.id and t.is_senior_teacher and not b.is_senior_teacher;
update public.teacher_records t set is_senior_teacher = true
  from private.v186_backup_flags b
 where b.id = t.id and b.is_senior_teacher and not t.is_senior_teacher;
set local session_replication_role = origin;

-- 3) استرجاع الدوال الخمس من التعريفات المحفوظة (الأصلية بدون p_group)
do $r$
declare r record;
begin
  for r in select def from private.v186_backup_defs loop
    execute r.def;
  end loop;
end $r$;
drop function if exists public.set_school_supervisor(uuid, uuid, text);
revoke all on function public.set_school_supervisor(uuid, uuid) from public, anon;
grant execute on function public.set_school_supervisor(uuid, uuid) to authenticated, service_role;

-- 4) الفهرس الفريد الأصلي (مشرف واحد نشط لكل مدرسة أصلية)
drop index if exists public.one_active_senior_teacher_per_school;
create unique index one_active_senior_teacher_per_school
  on public.teacher_records using btree (home_school_id)
  where (is_senior_teacher and active and home_school_id is not null);

-- 5) جدول اختيارات الموجه: عودة المفتاح إلى school_id وإزالة grp واسترجاع الصفوف
delete from public.school_supervisor_choice;
alter table public.school_supervisor_choice drop constraint school_supervisor_choice_pkey;
alter table public.school_supervisor_choice drop column grp;
alter table public.school_supervisor_choice add constraint school_supervisor_choice_pkey primary key (school_id);
insert into public.school_supervisor_choice (school_id, teacher_id, note, chosen_at, chosen_by)
select school_id, teacher_id, note, chosen_at, chosen_by from private.v186_backup_choice;

-- 6) سجل المدرسة الأصلية الذي أُضيف لهالة سيد أحمد
delete from public.teacher_school_assignments
 where id = (select row_id from private.v186_backup_rows where what = 'hala_home_tsa');

-- 7) إزالة الأعمدة والدوال المساعدة والمشغّلات الجديدة
drop function if exists private.schools_sup_group_trigger();
drop function if exists private.teacher_records_sup_group_trigger();
drop function if exists private.sup_group_of(uuid, text);
drop function if exists private.sup_group_key(text);
alter table public.teacher_records drop column sup_group;
alter table public.schools drop column supervise_by_specialty;

-- 8) تحقق: الأعلام والاختيارات مطابقة لما قبل الهجرة
do $v$
declare v_bad int; v_c1 int; v_c2 int;
begin
  select count(*) into v_bad from public.teacher_records t join private.v186_backup_flags b on b.id = t.id
   where t.is_senior_teacher is distinct from b.is_senior_teacher;
  if v_bad > 0 then raise exception 'rollback v186: % معلمًا لم تعد أعلامهم', v_bad; end if;
  select count(*) into v_c1 from public.school_supervisor_choice;
  select count(*) into v_c2 from private.v186_backup_choice;
  if v_c1 <> v_c2 then raise exception 'rollback v186: اختيارات % والمتوقع %', v_c1, v_c2; end if;
end $v$;

commit;
