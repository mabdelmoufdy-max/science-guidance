-- v446: قفل دورَي المعلم وحساب المدرسة في البرنامج الرئيسي.
create table private.v446_backup_user_roles as
select * from public.user_roles where role in ('teacher', 'senior_teacher');
alter table private.v446_backup_user_roles enable row level security;
revoke all on private.v446_backup_user_roles from public, anon, authenticated;

do $migration$
declare
  target record;
  def text;
begin
  for target in select * from (values
      ('public.sync_teacher_record_user_roles()'::regprocedure, $old$values (new.profile_id, 'teacher'::public.app_role, new.active, null)$old$, $new$values (new.profile_id, 'teacher'::public.app_role, false, null)$new$),
      ('public.sync_teacher_record_user_roles()'::regprocedure, $old$coalesce(new.active and (new.is_senior_teacher or private.school_data_officer_teacher(new.home_school_id) = new.id), false), null$old$, $new$false, null$new$),
      ('private.sync_school_login_role(uuid)'::regprocedure, $old$coalesce(tr.active and (tr.is_senior_teacher or private.school_data_officer_teacher(tr.home_school_id) = tr.id), false), null$old$, $new$false, null$new$)
  ) edits(fn, old_text, new_text) loop
    def := pg_get_functiondef(target.fn);
    if length(def) - length(replace(def, target.old_text, '')) <> length(target.old_text) then
      raise exception 'v446: expected exactly one match in %', target.fn;
    end if;
    execute replace(def, target.old_text, target.new_text);
  end loop;
end
$migration$;

update public.user_roles
set is_active = false
where role in ('teacher', 'senior_teacher') and is_active;
