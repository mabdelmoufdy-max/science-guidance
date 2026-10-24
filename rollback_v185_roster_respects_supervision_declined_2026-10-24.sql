-- استرجاع v185: يزيل سطري supervision_declined من دالتي الكشف. شغّله قبل rollback_v184 ثم rollback_v183 إن احتجت الكل.
do $mig$
declare d text; o text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_roster';
  o := d;
  d := replace(d, E'      and not exists (select 1 from public.supervision_declined sd where sd.teacher_id=tr.id and sd.school_id=p_school_id)  -- v185\n', '');
  if d=o then raise exception 'roster: not found'; end if;
  execute d;
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_rosters_all';
  o := d;
  d := replace(d, E'      and not exists (select 1 from public.supervision_declined sd where sd.teacher_id=tr.id and sd.school_id=p.sid)  -- v185\n', '');
  if d=o then raise exception 'all: not found'; end if;
  execute d;
end
$mig$;
