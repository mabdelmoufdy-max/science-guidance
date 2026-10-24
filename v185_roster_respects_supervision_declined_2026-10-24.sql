-- v185 (2026-10-24، بطلب المستخدم «نفذ»): كشف المدرسة يحترم supervision_declined في اختيار الأقدم (كما تفعل sync_school_senior_teacher).
-- طُبِّق من الجلسة. لا تُشغّله مرة ثانية. الاسترجاع: rollback_v185_roster_respects_supervision_declined_2026-10-24.sql
do $mig$
declare d text; o text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_roster';
  o := d;
  d := replace(d, E'      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p_school_id)\n',
    E'      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p_school_id)\n      and not exists (select 1 from public.supervision_declined sd where sd.teacher_id=tr.id and sd.school_id=p_school_id)  -- v185\n');
  if d=o then raise exception 'roster: not replaced'; end if;
  execute d;
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_rosters_all';
  o := d;
  d := replace(d, E'      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p.sid)  -- v183\n',
    E'      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p.sid)  -- v183\n      and not exists (select 1 from public.supervision_declined sd where sd.teacher_id=tr.id and sd.school_id=p.sid)  -- v185\n');
  if d=o then raise exception 'all: not replaced'; end if;
  execute d;
end
$mig$;
