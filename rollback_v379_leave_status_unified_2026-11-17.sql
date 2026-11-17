-- استرجاع v379 (يعتمد على private.v379_backup_functions و private.v379_backup_state — لا تُحذفا قبل التشغيل).
-- 1) نص دالة حفظ الإجازة السابق + المشغّل والقيمة الافتراضية
do $do$ declare r record; begin
  for r in select def from private.v379_backup_functions loop execute r.def; end loop;
end $do$;
drop trigger if exists trg_v379_leave_normalize on public.teacher_long_leaves;
drop function if exists private.v379_leave_normalize();
alter table public.teacher_long_leaves alter column renewal_status set default 'pending_renewal';
-- 2) إجازة سارة (تعود «بانتظار التجديد») وعلامة الإشراف واختياره
update public.teacher_long_leaves l set renewal_status = b.data->>'renewal_status', decision_number = b.data->>'decision_number',
  decision_date = (b.data->>'decision_date')::date, approved_by = (b.data->>'approved_by')::uuid, approved_at = (b.data->>'approved_at')::timestamptz
  from private.v379_backup_state b where b.kind = 'leave' and l.id = (b.data->>'id')::uuid;
update public.teacher_records set is_senior_teacher = (select (data->>'sara_is_senior')::boolean from private.v379_backup_state where kind='teacher_flags') where id = '3289fbb0-3c82-417b-9947-97672e17971d';
update public.teacher_records set is_senior_teacher = (select (data->>'yas_is_senior')::boolean from private.v379_backup_state where kind='teacher_flags') where id = '89ab19b9-1466-4e2c-9a2f-875fe33229fe';
update public.school_supervisor_choice c set teacher_id = (b.data->>'teacher_id')::uuid from private.v379_backup_state b where b.kind='supervisor_choice' and c.school_id = (b.data->>'school_id')::uuid and c.grp = b.data->>'grp';
-- 3) إعادة إسناد الفصول الثمانية (حصص الجدول لم تكن مدخلة)
do $do$ begin
  perform set_config('app.tp_timetable','on',true);
  insert into public.teaching_assignments select * from jsonb_populate_recordset(null::public.teaching_assignments, (select jsonb_agg(data) from private.v379_backup_state where kind='assignment'));
end $do$;
