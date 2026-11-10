-- استرجاع v331 (2026-11-10): يعيد دالتي استكمال البيانات إلى ما قبل السماح بتاريخ استلام العمل للمعلم
-- (submit_data_completion_change و review_data_completion_change) بعكس الاستبدالات النصية.
-- تنبيه: بعد الاسترجاع يعود رفض «تاريخ استلام العمل» للمعلم، وتعود كتابة التواريخ نصًا (تفشل لعمود date).
do $rb$
declare d text;
begin
  d := pg_get_functiondef('public.submit_data_completion_change(text,uuid,text,text)'::regprocedure);
  d := replace(d,$a$not in ('phone','job_title','appointment_date','work_start_date') then raise exception 'حقل معلم$a$,$a$not in ('phone','job_title','appointment_date') then raise exception 'حقل معلم$a$);
  d := replace(d,$a$if p_field_name in ('appointment_date','work_start_date') then cleanv:=cleanv::date::text; end if;
    execute format('update public.teacher_records set %I=$1%s, updated_at=now() where id=$2',p_field_name,case when p_field_name in ('appointment_date','work_start_date') then '::date' else '' end) using cleanv,p_entity_id;$a$,
    $a$if p_field_name='appointment_date' then cleanv:=cleanv::date::text; end if;
    execute format('update public.teacher_records set %I=$1, updated_at=now() where id=$2',p_field_name) using cleanv,p_entity_id;$a$);
  d := replace(d,$a$execute format('update public.supervisors set %I=$1%s where id=$2',p_field_name,case when p_field_name in ('appointment_date','work_start_date') then '::date' else '' end) using cleanv,p_entity_id;$a$,$a$execute format('update public.supervisors set %I=$1 where id=$2',p_field_name) using cleanv,p_entity_id;$a$);
  if position('%I=$1%s' in d)>0 or position('''appointment_date'',''work_start_date'') then raise exception ''حقل معلم' in d)>0 then raise exception 'rollback v331: submit not fully reverted'; end if;
  execute d;
  d := pg_get_functiondef('public.review_data_completion_change(uuid,text,text)'::regprocedure);
  d := replace(d,$a$when 'teacher' then rec.field_name = any(array['phone','job_title','appointment_date','work_start_date'])$a$,$a$when 'teacher' then rec.field_name = any(array['phone','job_title','appointment_date'])$a$);
  d := replace(d,$a$execute format('update public.teacher_records set %I=$1%s,updated_at=now() where id=$2',rec.field_name,case when rec.field_name in ('appointment_date','work_start_date') then '::date' else '' end) using rec.old_value,rec.entity_id;$a$,$a$execute format('update public.teacher_records set %I=$1,updated_at=now() where id=$2',rec.field_name) using rec.old_value,rec.entity_id;$a$);
  d := replace(d,$a$execute format('update public.supervisors set %I=$1%s where id=$2',rec.field_name,case when rec.field_name in ('appointment_date','work_start_date') then '::date' else '' end) using rec.old_value,rec.entity_id;$a$,$a$execute format('update public.supervisors set %I=$1 where id=$2',rec.field_name) using rec.old_value,rec.entity_id;$a$);
  if position('%I=$1%s' in d)>0 then raise exception 'rollback v331: review not fully reverted'; end if;
  execute d;
end
$rb$;
