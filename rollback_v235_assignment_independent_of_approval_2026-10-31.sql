-- استرجاع v235: يعيد الدالتين والسياسة كما كانت قبل 2026-10-31 (قفل الإسناد/الإلغاء بحالة الاعتماد).
-- يُشغَّل من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new

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
    insert into public.school_submissions(
      school_id,academic_year_id,term_id,status,entry_source,last_changed_by
    ) values(
      p_school_id,p_academic_year_id,p_term_id,'in_progress',p_entry_source,auth.uid()
    ) returning * into v_sub;
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

CREATE OR REPLACE FUNCTION public.unassign_class_atomic(p_assignment_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare v_role public.app_role:=public.current_app_role(); v_row public.teaching_assignments%rowtype; v_school uuid; v_status public.school_status;
begin
 if v_role not in ('admin','senior_teacher') then raise exception 'لا توجد صلاحية لإلغاء الإسناد'; end if;
 select a.* into v_row from public.teaching_assignments a where a.id=p_assignment_id for update;
 if not found then return jsonb_build_object('removed',false); end if;
 select c.school_id into v_school from public.school_classes c where c.id=v_row.class_id;
 select ss.status into v_status from public.school_submissions ss where ss.school_id=v_school and ss.term_id=v_row.term_id;
 if v_status='approved' then raise exception 'لا يمكن التراجع بعد الاعتماد النهائي'; end if;
 delete from public.teaching_assignments where id=p_assignment_id;
 return jsonb_build_object('removed',true,'assignment_id',p_assignment_id,'class_id',v_row.class_id,'teacher_id',v_row.teacher_id,'weekly_periods',v_row.weekly_periods);
end;$function$;

alter policy teaching_coord_remove on public.teaching_assignments
  using (
    ((select public.current_app_role()) = 'stage_coordinator'::public.app_role)
    and exists (
      select 1 from public.school_classes c
      where c.id = teaching_assignments.class_id
        and private.can_access_stage(c.stage)
        and not exists (
          select 1 from public.school_submissions ss
          where ss.school_id = c.school_id
            and ss.term_id = teaching_assignments.term_id
            and ss.status = 'approved'::public.school_status
        )
    )
  );

-- المتوقع: بلا أخطاء. بعدها يعود منع المنسق من الإسناد في المدارس المرسلة للاعتماد ومنع الإلغاء بعد الاعتماد النهائي.
