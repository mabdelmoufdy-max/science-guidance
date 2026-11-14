-- استرجاع v377: يعيد نص الدالتين من النسخة المحفوظة (لا تحذف private.v377_backup_functions قبل التشغيل).
do $do$ declare r record; begin
  for r in select def from private.v377_backup_functions loop execute r.def; end loop;
end $do$;
drop function if exists private.v377_solo_permanent(uuid);
