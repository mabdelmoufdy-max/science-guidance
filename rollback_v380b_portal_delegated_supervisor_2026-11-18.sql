-- استرجاع v380b: يعيد نص الدالتين من النسخة المحفوظة (لا تحذف private.v380b_backup_functions قبل التشغيل).
do $do$ declare r record; begin
  for r in select def from private.v380b_backup_functions loop execute r.def; end loop;
end $do$;
