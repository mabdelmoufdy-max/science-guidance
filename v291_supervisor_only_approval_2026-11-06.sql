-- v291 (2026-11-06) بقرار المستخدم «نفذ أ»:
-- الاعتماد لموجه المدرسة وحده (موجه المدرسة المباشر، أو أي موجه مادة لها في الثانوي)،
-- وإلغاء دور مدير المدرسة في الاعتماد، والمنسق (لمرحلته) والمدير: إعادة للتعديل فقط ولو بعد الاعتماد.
-- مشرف المادة لم يعد يعتمد مدرسته تلقائيًا عند الإسناد/إضافة الفصول؛ يرسل للاعتماد فقط.
-- الاسترجاع: rollback_v291_supervisor_only_approval_2026-11-06.sql (يعتمد على private.v291_backup_* — لا تُحذف).

create table if not exists private.v291_backup_school_authority as
  select id, approval_authority from public.schools;

create table if not exists private.v291_backup_functions as
  select 'public.review_school_submission_atomic'::text as fn,
         pg_get_functiondef('public.review_school_submission_atomic'::regproc) as def
  union all
  select 'private.senior_teacher_direct_approve_school',
         pg_get_functiondef('private.senior_teacher_direct_approve_school'::regproc);

-- 1) جهة الاعتماد = موجه المدرسة لكل المدارس (بدون مشغلات حتى لا تتغير row_version/updated_at أو الإشراف)
alter table public.schools disable trigger trg_schools_row_version;
alter table public.schools disable trigger trg_schools_updated_at;
alter table public.schools disable trigger trg_schools_sup_group;
alter table public.schools disable trigger trg_enforce_school_identity;
alter table public.schools disable trigger trg_link_budget_reference_school;
alter table public.schools disable trigger trg_link_teacher_reference_school;

update public.schools set approval_authority='supervisor'
 where approval_authority is distinct from 'supervisor';

alter table public.schools enable trigger trg_schools_row_version;
alter table public.schools enable trigger trg_schools_updated_at;
alter table public.schools enable trigger trg_schools_sup_group;
alter table public.schools enable trigger trg_enforce_school_identity;
alter table public.schools enable trigger trg_link_budget_reference_school;
alter table public.schools enable trigger trg_link_teacher_reference_school;

alter table public.schools alter column approval_authority set default 'supervisor';

insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, new_data)
select (select ur.profile_id from public.user_roles ur where ur.role='admin' and ur.is_active limit 1),
       'admin', 'v291_approval_authority_supervisor', 'schools', 'all',
       jsonb_build_object('to','supervisor',
         'from', (select jsonb_object_agg(approval_authority, n) from (select approval_authority, count(*) n from private.v291_backup_school_authority group by 1) b));

-- 2) review_school_submission_atomic: الاعتماد للموجه فقط؛ الإعادة للموجه/المنسق/المدير (المنسق والمدير ولو بعد الاعتماد)
do $mig$
declare
  v_def text := pg_get_functiondef('public.review_school_submission_atomic'::regproc);
  v_old1 text := E'  if not (\n    (v_authority=''admin'' and v_role=''admin'')\n    or (v_authority=''supervisor'' and v_role=''supervisor'' and v_supervisor=public.current_supervisor_id())\n    or (v_authority=''school_manager'' and v_role=''school_manager'' and v_manager=auth.uid())\n  ) then\n    raise exception ''لا توجد صلاحية لاعتماد هذه المدرسة وفق جهة الاعتماد المحددة'';\n  end if;';
  v_new1 text := E'  -- v291: الاعتماد لموجه المدرسة وحده؛ المنسق (مرحلته) والمدير: إعادة للتعديل فقط\n  if p_action=''approve'' then\n    if not (v_role=''supervisor'' and private.supervises_school(v_sub.school_id, public.current_supervisor_id())) then\n      raise exception ''الاعتماد لموجه المدرسة فقط'';\n    end if;\n  elsif not (\n    (v_role=''supervisor'' and private.supervises_school(v_sub.school_id, public.current_supervisor_id()))\n    or (v_role=''stage_coordinator'' and private.can_access_stage((select s.stage from public.schools s where s.id=v_sub.school_id)))\n    or v_role=''admin''\n  ) then\n    raise exception ''لا توجد صلاحية لإعادة هذه المدرسة للتعديل'';\n  end if;';
  v_old2 text := E'  if v_sub.status<>''pending_manager_approval'' then raise exception ''الحزمة لم تعد في حالة انتظار الاعتماد''; end if;';
  v_new2 text := E'  if not (v_sub.status=''pending_manager_approval''\n          or (p_action=''return'' and v_sub.status=''approved'' and v_role in (''stage_coordinator'',''admin''))) then\n    raise exception ''الحزمة لم تعد في حالة انتظار الاعتماد'';\n  end if;';
begin
  if (length(v_def)-length(replace(v_def, v_old1, '')))/length(v_old1) <> 1 then raise exception 'v291: snippet 1 not matched exactly once'; end if;
  if (length(v_def)-length(replace(v_def, v_old2, '')))/length(v_old2) <> 1 then raise exception 'v291: snippet 2 not matched exactly once'; end if;
  v_def := replace(replace(v_def, v_old1, v_new1), v_old2, v_new2);
  execute v_def;
end
$mig$;

alter function public.review_school_submission_atomic(uuid, text, text, bigint, text) security definer;

-- 3) مشرف المادة: لا اعتماد مباشر؛ تبقى مزامنة عدد الفصول فقط
create or replace function private.senior_teacher_direct_approve_school(p_school_id uuid, p_academic_year_id uuid, p_term_id uuid, p_reason text default 'تعديل بيانات المدرسة واعتمادها مباشرة بواسطة مشرف المادة'::text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public', 'pg_temp'
as $function$
declare
  v_actor uuid:=auth.uid();
  v_role public.app_role:=private.current_app_role();
  v_home uuid:=private.current_home_school_id();
  v_class_count integer:=0;
  v_status text;
begin
  -- v291: الاعتماد لموجه المدرسة وحده؛ تعديل مشرف المادة لا يعتمد المدرسة (يرسلها للاعتماد من «الإرسال للاعتماد»)
  if v_actor is null or v_role<>'senior_teacher'::public.app_role then
    raise exception 'هذه العملية متاحة لمشرف المادة فقط' using errcode='42501';
  end if;
  if v_home is null or v_home<>p_school_id then
    raise exception 'لا يمكنك تعديل بيانات مدرسة أخرى' using errcode='42501';
  end if;

  select count(*) into v_class_count
  from public.school_classes c
  where c.school_id=p_school_id and c.term_id=p_term_id;

  update public.schools
     set class_count=v_class_count, updated_at=now()
   where id=p_school_id and coalesce(class_count,0)<v_class_count;

  select ss.status::text into v_status
  from public.school_submissions ss
  where ss.school_id=p_school_id and ss.term_id=p_term_id;

  return jsonb_build_object('school_id',p_school_id,'status',coalesce(v_status,'not_started'),'class_count',v_class_count,'approved',false);
end
$function$;
