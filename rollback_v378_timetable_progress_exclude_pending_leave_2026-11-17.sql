-- استرجاع v378: يعيد نص الدالة من النسخة المحفوظة (لا تحذف private.v378_backup_functions قبل التشغيل).
do $do$ declare r record; begin
  for r in select def from private.v378_backup_functions loop execute r.def; end loop;
end $do$;
