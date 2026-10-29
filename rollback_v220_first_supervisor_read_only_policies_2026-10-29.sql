-- استرجاع v220: يعيد نص السياسات الأصلي (مع first_supervisor) من private.v220_policy_backup.
do $$
declare r record;
begin
 for r in select * from private.v220_policy_backup loop
  execute format('alter policy %I on %I.%I %s %s', r.policyname, r.schemaname, r.tablename,
    case when r.qual is not null then 'using ('||r.qual||')' else '' end,
    case when r.with_check is not null then 'with check ('||r.with_check||')' else '' end);
 end loop;
end $$;
