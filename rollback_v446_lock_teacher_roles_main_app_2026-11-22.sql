-- v446: استعادة منطق مزامنة الدورين وحالتيهما قبل الترحيل.
begin;
do $rollback$
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
    if length(def) - length(replace(def, target.new_text, '')) <> length(target.new_text) then
      raise exception 'v446 rollback: expected exactly one match in %', target.fn;
    end if;
    execute replace(def, target.new_text, target.old_text);
  end loop;
end
$rollback$;

update public.user_roles u
set is_active = b.is_active
from private.v446_backup_user_roles b
where u.profile_id = b.profile_id and u.role = b.role
  and u.is_active is distinct from b.is_active;
drop table private.v446_backup_user_roles;
commit;
