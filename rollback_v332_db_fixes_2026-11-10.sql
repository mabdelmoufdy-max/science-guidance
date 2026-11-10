-- استرجاع إصلاحات قاعدة البيانات v332 (2026-11-10). شغّل الجزء المطلوب فقط.
-- (أ) v332a_login_role_null_fix — يعيد الصيغة التي قد تعطي is_active فارغة
do $rb$
declare d text;
begin
  d := pg_get_functiondef('public.sync_teacher_record_user_roles()'::regprocedure);
  d := replace(d,$a$coalesce(new.active and (new.is_senior_teacher or private.school_data_officer_teacher(new.home_school_id) = new.id), false)$a$,
                 $a$(new.active and (new.is_senior_teacher or private.school_data_officer_teacher(new.home_school_id) = new.id))$a$);
  execute d;
  d := pg_get_functiondef('private.sync_school_login_role(uuid)'::regprocedure);
  d := replace(d,$a$coalesce(tr.active and (tr.is_senior_teacher or private.school_data_officer_teacher(tr.home_school_id) = tr.id), false)$a$,
                 $a$(tr.active and (tr.is_senior_teacher or private.school_data_officer_teacher(tr.home_school_id) = tr.id))$a$);
  execute d;
end $rb$;

-- (ب) v332b_move_clears_supervision — يلغي إلغاء الإشراف التلقائي عند النقل
-- (أسطر school_supervisor_choice المحذوفة بسببه محفوظة في audit_log action='supervision_released_on_move' عمود old_data->'choice')
drop trigger if exists trg_v332_move_clears_supervision on public.teacher_records;
drop trigger if exists trg_v332_move_sync_login_role on public.teacher_records;
drop function if exists private.v332_move_clears_supervision();

-- (ج) v332c_teacher_grade_date_completion — يزيل grade_acquired_date من استكمال البيانات
do $rb$
declare d text;
begin
  d := pg_get_functiondef('public.submit_data_completion_change(text,uuid,text,text)'::regprocedure);
  d := replace(d,$a$('phone','job_title','appointment_date','work_start_date','grade_acquired_date')$a$,$a$('phone','job_title','appointment_date','work_start_date')$a$);
  d := replace(d,$a$p_field_name in ('appointment_date','work_start_date','grade_acquired_date')$a$,$a$p_field_name in ('appointment_date','work_start_date')$a$);
  execute d;
  d := pg_get_functiondef('public.review_data_completion_change(uuid,text,text)'::regprocedure);
  d := replace(d,$a$array['phone','job_title','appointment_date','work_start_date','grade_acquired_date']$a$,$a$array['phone','job_title','appointment_date','work_start_date']$a$);
  d := replace(d,$a$rec.field_name in ('appointment_date','work_start_date','grade_acquired_date')$a$,$a$rec.field_name in ('appointment_date','work_start_date')$a$);
  execute d;
end $rb$;

-- (د) v332d_delete_school_atomic — يلغي دالة حذف المدرسة (الزر يعود لخطأ «الدالة غير موجودة»)
-- المدارس المحذوفة بها محفوظة في audit_log action='admin_delete_school' (old_data: school + links)
drop function if exists public.delete_school_atomic_v96(uuid, text);
