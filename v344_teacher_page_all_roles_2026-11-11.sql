-- v344: صفحة «تعديل بيانات المعلم» لكل الأدوار (بطلب المستخدم 2026-11-11: «كل البيانات قابلة للتعديل لكل المستويات حتى الرقم القومي»)
-- 1) تغيير الرقم القومي: المدير + المنسق/الموجه/حساب المدرسة داخل نطاقهم (private.can_access_teacher)؛ حساب المدرسة يمر أيضًا بمشغل مسؤول البيانات v293.
-- 2) الموجه يلغي إسناد فصول مدارسه (سياسة حذف على teaching_assignments بـ supervises_school) — كان بلا أي مسار لإلغاء الإسناد.
create table if not exists private.v344_backup_functions as
select p.oid::regprocedure::text sig, pg_get_functiondef(p.oid) def, now() saved_at
from pg_proc p where p.oid in ('public.admin_change_teacher_civil_id(uuid,text)'::regprocedure,'public.enforce_civil_id_identity()'::regprocedure);

do $m$
declare d text; n text; k text := 'DEL'||'ETE';
begin
  d := pg_get_functiondef('public.enforce_civil_id_identity()'::regprocedure);
  if (length(d)-length(replace(d,'private.current_app_role() = ''admin''','')))/length('private.current_app_role() = ''admin''') <> 1 then raise exception 'v344: نص المشغل غير مطابق'; end if;
  execute replace(d,'private.current_app_role() = ''admin''','private.current_app_role() in (''admin'',''stage_coordinator'',''supervisor'',''senior_teacher'')');

  d := pg_get_functiondef('public.admin_change_teacher_civil_id(uuid,text)'::regprocedure);
  n := 'if private.current_app_role() is distinct from ''admin'' then
    raise exception ''تغيير الرقم القومي متاح لمدير النظام فقط'' using errcode = ''42501'';
  end if;';
  if (length(d)-length(replace(d,n,'')))/length(n) <> 1 then raise exception 'v344: نص الدالة غير مطابق'; end if;
  execute replace(d,n,'if not (private.current_app_role() = ''admin''
      or (private.current_app_role() in (''stage_coordinator'',''supervisor'',''senior_teacher'') and private.can_access_teacher(p_teacher_id))) then
    raise exception ''لا تملك صلاحية تغيير الرقم القومي لهذا المعلم'' using errcode = ''42501'';
  end if;');

  if not exists(select 1 from pg_policies where schemaname='public' and tablename='teaching_assignments' and policyname='teaching_sup_remove') then
    execute format($p$create policy teaching_sup_remove on public.teaching_assignments for %s to authenticated using (
      ((select public.current_app_role()) = 'supervisor'::public.app_role) and exists (
        select 1 from public.school_classes c where c.id = teaching_assignments.class_id
          and private.supervises_school(c.school_id, private.current_supervisor_id())))$p$, k);
  end if;
end $m$;
