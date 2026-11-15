-- استرجاع v386: الفصل الجديد في الابتدائي يعود لصفر حصص (الدالتان كما كانتا).
do $$
declare d text; fn text;
begin
 foreach fn in array array['seed_class_curriculum_subjects','sync_class_curriculum_requirements'] loop
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='public' and p.proname=fn;
  execute replace(d, 'when new.stage=''ابتدائي'' then 3 else 0 end', 'else 0 end');
 end loop;
end $$;
