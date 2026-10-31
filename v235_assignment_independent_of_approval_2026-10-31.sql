-- v235 (2026-10-31، بطلب المستخدم «نفذ أ»): الإسناد وإلغاء الإسناد لا يرتبطان بحالة اعتماد المدرسة.
-- على مدار العام ينتدب معلمون وتتغير الفصول: الفصل غير المسند يُسند، وإلغاء الإسناد يعيده غير مسند،
-- أيًّا كانت حالة الطلب (قيد الإدخال/بانتظار الاعتماد/معتمد). حالة الاعتماد نفسها لا تتغير بالإسناد أو إلغائه.
-- الصلاحيات (من يُسند ومن يلغي) بلا تغيير.
-- الاسترجاع: rollback_v235_assignment_independent_of_approval_2026-10-31.sql

-- 1) كان المنسق لا يستطيع حجز طلب «بانتظار الاعتماد/معتمد» (سياسة submissions_coord_update) فتظنه الدالة غير موجود
--    وتحاول إنشاءه فيرفضه القيد الفريد (school_id, term_id) فتُظهر assign_class_atomic «هذا الفصل مسند بالفعل».
create or replace function public.ensure_school_submission_in_progress_atomic(p_school_id uuid, p_academic_year_id uuid, p_term_id uuid, p_entry_source text default 'school'::text)
 returns jsonb
 language plpgsql
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
declare
  v_sub public.school_submissions%rowtype;
begin
  -- Read-only existence/access check. Do not use FOR UPDATE on schools here,
  -- because subject supervisors have SELECT access to their school but do not
  -- have UPDATE rights on the schools master row.
  perform 1 from public.schools where id=p_school_id;
  if not found then
    raise exception 'المدرسة غير موجودة أو غير متاحة لهذا الحساب';
  end if;

  select * into v_sub
  from public.school_submissions
  where school_id=p_school_id and term_id=p_term_id
  for update;

  if not found then
    -- v235: قد يكون الطلب موجودًا ولا يملك هذا الدور تعديله (مثل المنسق بعد الإرسال للاعتماد أو بعده):
    -- لا إنشاء ولا تغيير في حالته.
    select * into v_sub
    from public.school_submissions
    where school_id=p_school_id and term_id=p_term_id;
    if not found then
      insert into public.school_submissions(
        school_id,academic_year_id,term_id,status,entry_source,last_changed_by
      ) values(
        p_school_id,p_academic_year_id,p_term_id,'in_progress',p_entry_source,auth.uid()
      ) returning * into v_sub;
    end if;
  elsif v_sub.status in ('in_progress','returned_for_edit') then
    update public.school_submissions
       set status='in_progress',
           return_reason=null,
           last_changed_by=auth.uid()
     where id=v_sub.id
     returning * into v_sub;
  end if;

  return jsonb_build_object('id',v_sub.id,'status',v_sub.status,'row_version',v_sub.row_version);
end;
$function$;

-- 2) unassign_class_atomic: حذف سطري «لا يمكن التراجع بعد الاعتماد النهائي» فقط (بقية الدالة كما هي).
--    التعديل من نص الدالة المخزن نفسه (يتوقف إن لم يجد السطرين).
do $v235$
declare d text; old_txt text;
begin
  d := pg_get_functiondef('public.unassign_class_atomic(uuid)'::regprocedure);
  old_txt := ' select ss.status into v_status from public.school_submissions ss where ss.school_id=v_school and ss.term_id=v_row.term_id;'||chr(10)
          || ' if v_status=''approved'' then raise exception ''لا يمكن التراجع بعد الاعتماد النهائي''; end if;'||chr(10);
  if strpos(d, old_txt) = 0 then
    raise exception 'v235: لم يُعثر على سطري قفل الاعتماد في unassign_class_atomic';
  end if;
  execute replace(d, old_txt, '');
end
$v235$;

-- 3) سياسة إلغاء المنسق للإسناد: بلا شرط «المدرسة غير معتمدة».
alter policy teaching_coord_remove on public.teaching_assignments
  using (
    ((select public.current_app_role()) = 'stage_coordinator'::public.app_role)
    and exists (
      select 1 from public.school_classes c
      where c.id = teaching_assignments.class_id
        and private.can_access_stage(c.stage)
    )
  );
