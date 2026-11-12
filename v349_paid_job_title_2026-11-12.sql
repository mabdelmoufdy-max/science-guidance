-- v349: المسمى الوظيفي لمعلم الأجر = «معلم بالأجر» تلقائيًا (بقرار المستخدم 2026-11-12 «أ ونعم»)
-- لا أثر على الأنصبة (teacher_workload_target يعيد null لمعلم الأجر مهما كان مسماه).
create or replace function private.v349_paid_job_title() returns trigger language plpgsql set search_path to 'pg_catalog','public' as $$
begin
  if new.work_type = 'paid'::public.work_type then
    new.job_title := 'معلم بالأجر';
  elsif tg_op = 'UPDATE' and old.work_type = 'paid'::public.work_type and new.job_title = 'معلم بالأجر' then
    new.job_title := null;  -- عند التحويل لثابت يختار المستخدم الدرجة الحقيقية
  end if;
  return new;
end $$;
create trigger trg_v349_paid_job_title before insert or update of work_type, job_title on public.teacher_records
  for each row execute function private.v349_paid_job_title();

create table if not exists private.v349_backup_paid_job_title as
  select id, job_title, now() saved_at from public.teacher_records
  where work_type='paid' and job_title is distinct from 'معلم بالأجر';
revoke all on private.v349_backup_paid_job_title from anon, authenticated;

alter table public.teacher_records disable trigger trg_teacher_records_updated_at;
alter table public.teacher_records disable trigger trg_teacher_records_row_version;
alter table public.teacher_records disable trigger trg_audit_teacher_record_changes;
alter table public.teacher_records disable trigger teacher_records_auto_senior_teacher;
update public.teacher_records set job_title='معلم بالأجر' where id in (select id from private.v349_backup_paid_job_title);
alter table public.teacher_records enable trigger trg_teacher_records_updated_at;
alter table public.teacher_records enable trigger trg_teacher_records_row_version;
alter table public.teacher_records enable trigger trg_audit_teacher_record_changes;
alter table public.teacher_records enable trigger teacher_records_auto_senior_teacher;

insert into public.audit_log(actor_role,action,entity_type,new_data)
select 'admin','v349_paid_job_title','teacher_records',
  jsonb_build_object('changed',(select count(*) from private.v349_backup_paid_job_title),'job_title','معلم بالأجر');
