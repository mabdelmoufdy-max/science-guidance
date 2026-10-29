-- v216 (2026-10-29): اعتماد المنسق يُنشئ طلبًا في مركز الاعتماد.
-- 1) جهة اعتماد مدارس الثانوي الـ12 = مدير النظام. 2) دالة coordinator_submit_school_for_approval. 3) السماح بمصدر 'stage_coordinator'.
-- شغّله من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- كل أمر يُنفَّذ على حدة؛ آمن عند التكرار.

alter table public.school_submissions drop constraint if exists school_submissions_entry_source_chk;
alter table public.school_submissions add constraint school_submissions_entry_source_chk
  check (entry_source = any (array['school','supervisor','first_supervisor','admin','stage_coordinator']));

create or replace function public.coordinator_submit_school_for_approval(p_school_id uuid, p_academic_year_id uuid, p_term_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_stage text; v_sub public.school_submissions%rowtype; v_assigned integer; v_authority text;
begin
  if auth.uid() is null then raise exception 'Unauthorized'; end if;
  if private.current_app_role() not in ('stage_coordinator','admin','first_supervisor') then
    raise exception 'لا توجد صلاحية لإرسال المدرسة للاعتماد';
  end if;
  select stage, approval_authority into v_stage, v_authority from public.schools where id=p_school_id;
  if not found then raise exception 'المدرسة غير موجودة'; end if;
  if not private.can_access_stage(v_stage) then raise exception 'المدرسة خارج مرحلتك'; end if;
  if not exists(select 1 from public.terms where id=p_term_id and academic_year_id=p_academic_year_id and is_active) then
    raise exception 'الفصل الدراسي غير نشط';
  end if;
  select count(distinct a.class_id)::integer into v_assigned
    from public.school_classes c join public.teaching_assignments a on a.class_id=c.id and a.term_id=p_term_id
   where c.school_id=p_school_id and c.term_id=p_term_id;
  if v_assigned=0 then raise exception 'لا توجد فصول مسندة لإرسالها للاعتماد. أسند فصلًا واحدًا على الأقل أولًا'; end if;
  select * into v_sub from public.school_submissions where school_id=p_school_id and term_id=p_term_id for update;
  if found and v_sub.status in ('approved','pending_manager_approval') then
    return jsonb_build_object('id',v_sub.id,'status',v_sub.status,'unchanged',true,'approval_authority',v_authority);
  end if;
  insert into public.school_submissions(school_id,academic_year_id,term_id,status,submitted_by,submitted_at,return_reason,last_changed_by,entry_source)
  values(p_school_id,p_academic_year_id,p_term_id,'pending_manager_approval',auth.uid(),now(),null,auth.uid(),'stage_coordinator')
  on conflict(school_id,term_id) do update set status='pending_manager_approval',submitted_by=auth.uid(),submitted_at=now(),
    return_reason=null,last_changed_by=auth.uid(),entry_source='stage_coordinator'
  returning * into v_sub;
  return jsonb_build_object('id',v_sub.id,'status',v_sub.status,'unchanged',false,'approval_authority',v_authority);
end;
$function$;

revoke all on function public.coordinator_submit_school_for_approval(uuid,uuid,uuid) from public, anon;
grant execute on function public.coordinator_submit_school_for_approval(uuid,uuid,uuid) to authenticated;

update public.schools set approval_authority='admin' where stage='ثانوي' and approval_authority='school_manager';
-- المتوقع: 12 صفًا. تحقق: select approval_authority,count(*) from public.schools where stage='ثانوي' group by 1;  -- admin = 12
