-- استرجاع v344: يعيد الدالتين من private.v344_backup_functions ويزيل سياسة الموجه
do $r$ declare r record; begin
  for r in select def from private.v344_backup_functions loop execute r.def; end loop;
end $r$;
drop policy if exists teaching_sup_remove on public.teaching_assignments;
