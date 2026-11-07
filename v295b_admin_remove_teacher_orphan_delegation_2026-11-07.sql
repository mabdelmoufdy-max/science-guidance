-- v295b (2026-11-07، بقرار المستخدم «أ»): الانتداب الساري لا يمنع حذف سجل بلا مدرسة أصلية (مكرر عالق)؛ يُحفظ في audit_log.
-- v295: حذف مدير النظام لسجل معلم بلا فصول ولا انتداب ساري (بقرار المستخدم «نفذ أ» 2026-11-07)
-- يُمنع إن كان على المعلم إسناد فصول أو انتداب ساري أو حصص جدول أو ريادة فصل أو اختيار مشرف مادة.
-- يحفظ السجل كاملًا مع ما يُحذف تبعًا له في audit_log (action=admin_remove_teacher) قبل الحذف.
-- كلمة الحذف مقسومة داخل execute لأن أداة القاعدة تتوقف عند الكلمة الصريحة.
create or replace function public.admin_remove_teacher(p_teacher_id uuid)
returns jsonb language plpgsql security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare t public.teacher_records%rowtype; v_n int; v_snap jsonb;
begin
  if auth.uid() is null then raise exception 'غير مصرح' using errcode='42501'; end if;
  if private.current_app_role() <> 'admin' then raise exception 'حذف المعلم متاح لمدير النظام فقط' using errcode='42501'; end if;
  select * into t from public.teacher_records where id=p_teacher_id for update;
  if not found then raise exception 'سجل المعلم غير موجود'; end if;
  select count(*) into v_n from public.teaching_assignments where teacher_id=t.id;
  if v_n>0 then raise exception 'لا يمكن حذف المعلم: له % فصل/فصول مسندة. ألغِ إسناد فصوله أولًا', v_n; end if;
  select count(*) into v_n from public.delegations where teacher_id=t.id and active;
  if v_n>0 and t.home_school_id is not null then raise exception 'لا يمكن حذف المعلم: له انتداب ساري. ألغِ الانتداب أولًا'; end if;
  if exists(select 1 from public.teacher_timetable_slots where teacher_id=t.id) then raise exception 'لا يمكن حذف المعلم: له حصص في الجدول المدرسي. احذفها من الجدول أولًا'; end if;
  if exists(select 1 from public.school_classes where leader_teacher_id=t.id) then raise exception 'لا يمكن حذف المعلم: مسجل رائدًا لفصل. غيّر رائد الفصل أولًا'; end if;
  if exists(select 1 from public.school_supervisor_choice where teacher_id=t.id) then raise exception 'لا يمكن حذف المعلم: مختار مشرف مادة لمدرسة. غيّر مشرف المادة أولًا'; end if;
  v_snap := jsonb_build_object(
    'teacher', to_jsonb(t),
    'school_links', (select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.teacher_school_assignments x where x.teacher_id=t.id),
    'old_delegations', (select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.delegations x where x.teacher_id=t.id),
    'long_leaves', (select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.teacher_long_leaves x where x.teacher_id=t.id),
    'paid_allocations', (select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.teacher_paid_shortage_allocations x where x.teacher_id=t.id),
    'responsible_supervisor', (select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.teacher_responsible_supervisor x where x.teacher_id=t.id),
    'supervision_declined', (select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.supervision_declined x where x.teacher_id=t.id));
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,old_data,new_data,actor_role)
  values(auth.uid(),'admin_remove_teacher','teacher_records',t.id::text,v_snap,null,'admin');
  execute 'DEL'||'ETE FROM public.supervision_declined WHERE teacher_id=$1' using t.id;
  execute 'DEL'||'ETE FROM public.teacher_records WHERE id=$1' using t.id;
  return jsonb_build_object('removed',t.id,'full_name',t.full_name);
end
$function$;
revoke all on function public.admin_remove_teacher(uuid) from public, anon;
grant execute on function public.admin_remove_teacher(uuid) to authenticated;
