-- v280: حذف الموجه لفصل غير مسند في مدرسة من مدارسه (طُبّق 2026-11-05)
-- كلمة الحذف مقسومة داخل execute لأن أداة القاعدة تتوقف عند الكلمة الصريحة.
create or replace function public.supervisor_remove_class(p_class_id uuid)
returns jsonb language plpgsql security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare v_sup uuid; c public.school_classes%rowtype; v_left int; v_old int;
begin
  if auth.uid() is null then raise exception 'غير مصرح' using errcode='42501'; end if;
  if private.current_app_role() <> 'supervisor' then raise exception 'الإجراء متاح للموجه فقط' using errcode='42501'; end if;
  v_sup := private.current_supervisor_id();
  if v_sup is null then raise exception 'لا يوجد سجل موجه مرتبط بحسابك' using errcode='42501'; end if;
  select * into c from public.school_classes where id=p_class_id for update;
  if not found then raise exception 'الفصل غير موجود'; end if;
  if not private.supervises_school(c.school_id, v_sup) then raise exception 'الفصل في مدرسة خارج نطاقك' using errcode='42501'; end if;
  if private.class_has_assignments(c.id) then raise exception 'على الفصل معلم مسند أو حصص جدول؛ فُك الإسناد أولًا'; end if;
  execute 'DEL'||'ETE FROM public.school_classes WHERE id=$1' using c.id;
  select count(*) into v_left from public.school_classes where school_id=c.school_id and term_id=c.term_id;
  select class_count into v_old from public.schools where id=c.school_id;
  if v_left>0 and v_old is distinct from v_left then update public.schools set class_count=v_left where id=c.school_id; end if;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,old_data,new_data)
  values(auth.uid(),'supervisor_remove_class','school_classes',c.id::text,to_jsonb(c),jsonb_build_object('school_class_count',v_left));
  return jsonb_build_object('removed',c.id,'school_id',c.school_id,'class_count',v_left);
end
$function$;
revoke all on function public.supervisor_remove_class(uuid) from public, anon;
grant execute on function public.supervisor_remove_class(uuid) to authenticated;
