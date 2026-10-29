-- استرجاع v220b: يعيد الدوال الأصلية من private.v220_function_backup.
do $$ declare r record; begin for r in select * from private.v220_function_backup loop execute r.def; end loop; end $$;
