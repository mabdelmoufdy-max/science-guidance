-- v448 rollback — Run in the project's SQL Editor. Keep the backup table.
do $rollback$
declare
  backup record;
begin
  if (select count(*) from private.v448_backup_functions) <> 4 then
    raise exception 'v448 rollback: expected four function backups';
  end if;

  for backup in select * from private.v448_backup_functions loop
    if pg_catalog.pg_get_functiondef(backup.signature::regprocedure)
       is distinct from backup.patched_definition then
      raise exception 'v448 rollback: definition changed since migration: %', backup.signature;
    end if;
    execute backup.original_definition;
  end loop;

  drop trigger v448_portal_actor on public.audit_log;
  drop function private.v448_portal_actor();
end;
$rollback$;

select 'v448 rollback complete' as status;
