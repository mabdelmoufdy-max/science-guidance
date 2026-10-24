-- v184 (2026-10-24، بطلب المستخدم: «من تعديل بيانات المعلم في تبويب الموجه والمنسق ومدير النظام الكل يستطيع أن يلغي إشراف أو يضيف إشراف لمعلم بشرط المدرسة الواحدة مشرف واحد»)
-- دالة set_school_supervisor تكتب اختيار الموجه في school_supervisor_choice (v183): مشرف واحد لكل مدرسة (المفتاح school_id)،
-- والمعلم يشرف على مدرسة واحدة فقط (فهرس فريد على teacher_id). الأدوار: admin، stage_coordinator، supervisor ضمن نطاق can_access_school.
-- طُبِّق 2026-10-24 من الجلسة (تجارب جافة ناجحة). لا تُشغّله مرة ثانية.
-- الاسترجاع: rollback_v184_set_school_supervisor_2026-10-24.sql
begin;
create unique index if not exists school_supervisor_choice_one_school_per_teacher on public.school_supervisor_choice(teacher_id) where teacher_id is not null;

create or replace function public.set_school_supervisor(p_school_id uuid, p_teacher_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $fn$
declare
  v_role public.app_role := private.current_app_role();
  v_prev uuid; v_other_school uuid; v_home uuid; v_prev_home uuid; v_name text; v_prev_name text;
begin
  if auth.uid() is null then raise exception 'Unauthorized' using errcode='42501'; end if;
  if v_role is null or v_role::text not in ('admin','stage_coordinator','supervisor') then
    raise exception 'تعديل مشرف المادة متاح للموجه ومنسق المرحلة ومدير النظام فقط' using errcode='42501';
  end if;
  if p_school_id is null or not private.can_access_school(p_school_id) then
    raise exception 'المدرسة خارج نطاق صلاحيتك' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('set_school_supervisor', 7242026));

  if p_teacher_id is not null then
    select tr.home_school_id, tr.full_name into v_home, v_name from public.teacher_records tr
     where tr.id=p_teacher_id and tr.active and tr.work_type='permanent'::public.work_type;
    if not found then raise exception 'مشرف المادة يجب أن يكون معلمًا ثابتًا نشطًا'; end if;
    if v_home is distinct from p_school_id and not exists (
      select 1 from public.delegations d where d.teacher_id=p_teacher_id and d.to_school_id=p_school_id and d.active
        and d.start_date<=current_date and (d.end_date is null or d.end_date>=current_date)) then
      raise exception 'المعلم ليس من معلمي هذه المدرسة (لا هي مدرسته الأصلية ولا منتدب إليها)';
    end if;
    if exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active
               where l.teacher_id=p_teacher_id and l.renewal_status='renewed') then
      raise exception 'المعلم في إجازة مجددة ولا يتولى الإشراف';
    end if;
    -- المعلم يشرف على مدرسة واحدة: يُرفع اختياره من أي مدرسة أخرى (تصبح بلا مشرف)
    select c.school_id into v_other_school from public.school_supervisor_choice c where c.teacher_id=p_teacher_id and c.school_id<>p_school_id;
    if v_other_school is null and v_home is distinct from p_school_id
       and exists (select 1 from public.teacher_records tr where tr.id=p_teacher_id and tr.is_senior_teacher)
       and not exists (select 1 from public.school_supervisor_choice c where c.school_id=v_home) then
      v_other_school := v_home;  -- كان مشرفًا في مدرسته الأصلية بالأقدمية
    end if;
    if v_other_school is not null then
      insert into public.school_supervisor_choice(school_id,teacher_id,note,chosen_at,chosen_by)
      values (v_other_school,null,'شاغر: نُقل مشرفها إلى مدرسة أخرى',now(),auth.uid())
      on conflict (school_id) do update set teacher_id=null, note=excluded.note, chosen_at=excluded.chosen_at, chosen_by=excluded.chosen_by;
    end if;
  end if;

  select c.teacher_id into v_prev from public.school_supervisor_choice c where c.school_id=p_school_id;
  if v_prev is null then
    select tr.id into v_prev from public.teacher_records tr where tr.home_school_id=p_school_id and tr.active and tr.is_senior_teacher limit 1;
  end if;
  select tr.home_school_id, tr.full_name into v_prev_home, v_prev_name from public.teacher_records tr where tr.id=v_prev;

  insert into public.school_supervisor_choice(school_id,teacher_id,note,chosen_at,chosen_by)
  values (p_school_id,p_teacher_id,case when p_teacher_id is null then 'إلغاء الإشراف من تعديل بيانات المعلم' else 'من تعديل بيانات المعلم' end,now(),auth.uid())
  on conflict (school_id) do update set teacher_id=excluded.teacher_id, note=excluded.note, chosen_at=excluded.chosen_at, chosen_by=excluded.chosen_by;

  perform private.sync_school_senior_teacher(s) from (
    select p_school_id s union select v_other_school union select v_home union select v_prev_home) x where s is not null;

  return jsonb_build_object('school_id',p_school_id,'teacher_id',p_teacher_id,'teacher_name',v_name,
    'previous_teacher_id',v_prev,'previous_teacher_name',v_prev_name,'cleared_school_id',v_other_school);
end
$fn$;
revoke all on function public.set_school_supervisor(uuid,uuid) from public, anon;
grant execute on function public.set_school_supervisor(uuid,uuid) to authenticated;

-- إصلاح v183: سطر الحماية في sync_school_senior_teacher كان يُبقي علامة is_senior_teacher لمعلم مختار في مدرسة أخرى،
-- فتصطدم بقيد one_active_senior_teacher_per_school عند اختيار مشرف لمدرسته الأصلية. إشراف المختار يُحتسب من الجدول لا من العلامة.
do $mig$
declare d text; o text;
begin
  d := pg_get_functiondef('private.sync_school_senior_teacher'::regproc);
  o := d;
  d := replace(d, E'    and tr.id is distinct from v_winner\n    and not exists (select 1 from public.school_supervisor_choice c3 where c3.teacher_id = tr.id and c3.school_id <> p_school_id)  -- v183\n',
    E'    and tr.id is distinct from v_winner\n');
  if d=o then raise exception 'sync: guard not found'; end if;
  execute d;
end
$mig$;
commit;
