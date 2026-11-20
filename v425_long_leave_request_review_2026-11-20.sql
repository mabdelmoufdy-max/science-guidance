-- v425 اعتماد الموجه لطلبات الإجازة الطويلة المرسلة من بوابة المعلمين — 2026-11-20
-- بقرار المستخدم: الاعتماد يلغي إسنادات المعلم في الفصل الدراسي الحالي تلقائيًا، والطلبات تظهر في الرئيسية للموجه والمنسق.
-- (1) long_leave_requests_pending(): الطلبات المعلّقة في نطاق الدور (admin / stage_coordinator / supervisor) بمدرسة المعلم الأصلية.
-- (2) long_leave_request_review(id, action, note, decision_number, decision_date):
--     approve: يلغي إسنادات المعلم في الفصل الحالي (حصص جدولها تُزال بالتتالي) ثم يسجّل الإجازة بـ save_teacher_long_leave_status
--              (فيُلغى الإشراف v379b ويُمنع الإسناد الجديد v419)؛ reject: يرفض بملاحظة. كلاهما audit.
-- إضافية فقط (دالتان جديدتان). يُشغَّل من SQL Editor لأن الدالة تحوي أمر إزالة الإسناد:
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new  — عند النجاح: «Success. No rows returned».

create or replace function public.long_leave_requests_pending()
returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public, private, pg_temp as $$
declare v_role public.app_role := public.current_app_role(); v_term uuid; v jsonb;
begin
  if auth.uid() is null or v_role is null or v_role <> all (array['admin','stage_coordinator','supervisor']::public.app_role[]) then
    return '[]'::jsonb;
  end if;
  select term_id into v_term from private.tp_active();
  select coalesce(jsonb_agg(x order by x ->> 'created_at'), '[]'::jsonb) into v from (
    select jsonb_build_object(
      'id', r.id, 'teacher_id', t.id, 'teacher', t.full_name, 'school', s.name, 'stage', s.stage,
      'type', r.leave_type, 'from', r.date_from, 'to', r.date_to, 'notes', r.notes, 'source', r.source,
      'requested_by', rb.full_name, 'created_at', r.created_at, 'is_senior', coalesce(t.is_senior_teacher, false),
      'assignments', coalesce((select jsonb_agg(jsonb_build_object('class', c.class_name, 'school', cs.name,
                         'subject', sj.subject_name, 'periods', a.weekly_periods) order by cs.name, c.grade_order, c.class_name)
                       from public.teaching_assignments a join public.school_classes c on c.id = a.class_id
                       join public.schools cs on cs.id = c.school_id left join public.curriculum_subjects sj on sj.id = a.subject_id
                      where a.teacher_id = t.id and a.term_id = v_term), '[]'::jsonb)) x
      from public.teacher_long_leave_requests r
      join public.teacher_records t on t.id = r.teacher_id
      join public.schools s on s.id = t.home_school_id
      left join public.teacher_records rb on rb.id = r.requested_by
     where r.status = 'pending' and t.active and public.can_access_school(t.home_school_id)
  ) q;
  return v;
end $$;

create or replace function public.long_leave_request_review(p_id uuid, p_action text, p_note text default null,
  p_decision_number text default null, p_decision_date date default null)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, private, pg_temp as $$
declare v_role public.app_role := public.current_app_role(); r public.teacher_long_leave_requests%rowtype;
  t public.teacher_records%rowtype; a record; v_removed jsonb; v_res jsonb;
begin
  if auth.uid() is null or v_role is null or v_role <> all (array['admin','stage_coordinator','supervisor']::public.app_role[]) then
    raise exception 'ليس لديك صلاحية اعتماد طلبات الإجازة';
  end if;
  if p_action not in ('approve','reject') then raise exception 'إجراء غير صحيح'; end if;
  if length(coalesce(p_note, '')) > 500 then raise exception 'الملاحظة طويلة'; end if;
  select * into r from public.teacher_long_leave_requests where id = p_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if r.status <> 'pending' then raise exception 'تمت مراجعة هذا الطلب أو سحبه'; end if;
  select * into t from public.teacher_records where id = r.teacher_id;
  if not found or not t.active or t.home_school_id is null then raise exception 'المعلم غير موجود أو غير نشط'; end if;
  if not public.can_access_school(t.home_school_id) then raise exception 'المعلم خارج نطاق صلاحيتك'; end if;
  select * into a from private.tp_active();

  if p_action = 'reject' then
    update public.teacher_long_leave_requests set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(),
      review_note = nullif(btrim(coalesce(p_note, '')), '') where id = p_id;
    insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
    values (auth.uid(), v_role, 'long_leave_request_rejected', 'teacher', t.id::text, to_jsonb(r),
            jsonb_build_object('request_id', p_id, 'note', p_note));
    return jsonb_build_object('ok', true, 'status', 'rejected');
  end if;

  -- الاعتماد: لقطة الإسنادات ثم إلغاؤها (حصص الجدول تُزال بالتتالي) ثم تسجيل الإجازة
  select coalesce(jsonb_agg(to_jsonb(ta)), '[]'::jsonb) into v_removed
    from public.teaching_assignments ta where ta.teacher_id = t.id and ta.term_id = a.term_id;
  delete from public.teaching_assignments where teacher_id = t.id and term_id = a.term_id;

  v_res := public.save_teacher_long_leave_status(t.id, a.year_id, r.leave_type, 'renewed', p_decision_number, p_decision_date,
             r.date_from, r.date_to, coalesce(r.notes, 'طلب من بوابة المعلمين'), null);

  update public.teacher_long_leave_requests set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(),
    review_note = nullif(btrim(coalesce(p_note, '')), ''), long_leave_id = (v_res ->> 'leave_id')::uuid where id = p_id;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (auth.uid(), v_role, 'long_leave_request_approved', 'teacher', t.id::text,
          jsonb_build_object('request', to_jsonb(r), 'removed_assignments', v_removed),
          jsonb_build_object('request_id', p_id, 'leave_id', v_res ->> 'leave_id', 'note', p_note,
                             'removed_count', jsonb_array_length(v_removed)));
  return jsonb_build_object('ok', true, 'status', 'approved', 'leave_id', v_res ->> 'leave_id',
                            'removed_count', jsonb_array_length(v_removed));
end $$;

revoke all on function public.long_leave_requests_pending() from public, anon;
revoke all on function public.long_leave_request_review(uuid, text, text, text, date) from public, anon;
grant execute on function public.long_leave_requests_pending() to authenticated;
grant execute on function public.long_leave_request_review(uuid, text, text, text, date) to authenticated;
