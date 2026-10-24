-- استرجاع v183 (2026-10-24): يعيد الدوال الثلاث كما كانت، ويحذف جدول اختيار الموجه، ويعيد الموجه المسؤول للمدارس الخمس وعلامة مشرف المادة كما كانت قبل v183.
-- يُشغَّل من SQL Editor.
begin;
do $mig$
declare d text; o text;
begin
  -- 1) private.school_teacher_roster
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_roster';
  o := d;
  d := replace(d, E'  ), supervisor_choice as (\n    select c.teacher_id from public.school_supervisor_choice c where c.school_id=p_school_id  -- v183\n  ), scope_supervisor as (\n    select tr.id as teacher_id\n    from public.teacher_records tr\n    join roster_ids ri on ri.id=tr.id\n    join supervisor_choice sc0 on sc0.teacher_id=tr.id\n    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active where l.teacher_id=tr.id and l.renewal_status=''renewed'')\n    union all\n    (select tr.id as teacher_id\n    from public.teacher_records tr\n    join roster_ids ri on ri.id=tr.id\n    where not exists (select 1 from supervisor_choice)\n      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p_school_id)\n      and tr.active', E'  ), scope_supervisor as (\n    select tr.id as teacher_id\n    from public.teacher_records tr\n    join roster_ids ri on ri.id=tr.id\n    where tr.active');
  if d=o then raise exception 'roster: scope_supervisor not replaced'; end if; o := d;
  d := replace(d, E'    limit 1)\n  ), scope_teaching as (', E'    limit 1\n  ), scope_teaching as (');
  if d=o then raise exception 'roster: limit not replaced'; end if; o := d;
  d := replace(d, E'        when ss.teacher_id=w.teacher_id then 2\n        when exists (select 1 from public.school_supervisor_choice c2 where c2.teacher_id=w.teacher_id and c2.school_id<>p_school_id) then 2  -- v183\n        else 0\n      end::integer as global_supervision_periods', E'        when ss.teacher_id=w.teacher_id then 2\n        else 0\n      end::integer as global_supervision_periods');
  if d=o then raise exception 'roster: global not replaced'; end if;
  execute d;

  -- 2) private.school_teacher_rosters_all
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_rosters_all';
  o := d;
  d := replace(d, E'    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p.sid)  -- v183\n      and not exists (select 1 from public.delegations d where d.teacher_id=tr.id and d.to_school_id=p.sid', E'    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.delegations d where d.teacher_id=tr.id and d.to_school_id=p.sid');
  if d=o then raise exception 'all: ranked not replaced'; end if; o := d;
  d := replace(d, E'  ), ss as (\n    select r.sid, r.tid from ranked r where r.rn=1 and not exists (select 1 from public.school_supervisor_choice c where c.school_id=r.sid)\n    union all  -- v183: اختيار الموجه\n    select p.sid, p.tid from pairs p\n    join public.school_supervisor_choice c on c.school_id=p.sid and c.teacher_id=p.tid\n    join public.teacher_records tr on tr.id=p.tid\n    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active where l.teacher_id=tr.id and l.renewal_status=''renewed'')\n  ),', E'  ), ss as (\n    select r.sid, r.tid from ranked r where r.rn=1\n  ),');
  if d=o then raise exception 'all: ss not replaced'; end if; o := d;
  d := replace(d, E'        when ss.tid=w.teacher_id then 2\n        when exists (select 1 from public.school_supervisor_choice c2 where c2.teacher_id=w.teacher_id and c2.school_id<>p.sid) then 2  -- v183\n        else 0\n      end::integer as global_supervision_periods,', E'        when ss.tid=w.teacher_id then 2\n        else 0\n      end::integer as global_supervision_periods,');
  if d=o then raise exception 'all: global not replaced'; end if;
  execute d;

  -- 3) private.sync_school_senior_teacher
  d := pg_get_functiondef('private.sync_school_senior_teacher'::regproc);
  o := d;
  d := replace(d, E'  where not exists (select 1 from public.supervision_declined sd where sd.teacher_id = tr.id and sd.school_id = p_school_id)\n    and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id = tr.id and c1.school_id <> p_school_id)  -- v183', E'  where not exists (select 1 from public.supervision_declined sd where sd.teacher_id = tr.id and sd.school_id = p_school_id)');
  if d=o then raise exception 'sync: winner filter not replaced'; end if; o := d;
  d := replace(d, E'  limit 1;\n\n  -- v183: اختيار الموجه يتقدم على الأقدمية (teacher_id فارغ = لا مشرف)\n  if exists (select 1 from public.school_supervisor_choice c where c.school_id = p_school_id) then\n    select c.teacher_id into v_winner from public.school_supervisor_choice c where c.school_id = p_school_id;\n  end if;\n\n  update public.teacher_records tr\n  set is_senior_teacher = false,', E'  limit 1;\n\n  update public.teacher_records tr\n  set is_senior_teacher = false,');
  if d=o then raise exception 'sync: choice not inserted'; end if; o := d;
  d := replace(d, E'    and tr.id is distinct from v_winner\n    and not exists (select 1 from public.school_supervisor_choice c3 where c3.teacher_id = tr.id and c3.school_id <> p_school_id)  -- v183\n', E'    and tr.id is distinct from v_winner\n');
  if d=o then raise exception 'sync: reset guard not replaced'; end if;
  execute d;
end
$mig$;

update public.schools set supervisor_id='4d69363b-0b47-4d94-8c2d-d0e38d8c0f0a' where id in ('ed4f660b-ff4b-4116-9fc0-689f6518183a','fdf478d1-2dbb-4b6c-9d1b-b390a90ce309'); -- المقربية، العبور ← محمد معله
update public.schools set supervisor_id='367e91fd-f844-4f9f-bc48-c8dedcbbac36' where id='1ee424cd-6713-41cc-8f26-f421d01087d0'; -- كوبري حجازة ← موسى محمد عبدالقادر
update public.schools set supervisor_id='bacb6309-6181-4afb-b005-c390df6295c5' where id='fe98af7a-ce7b-437a-ad26-a95b13c23c67'; -- نجع البرج ← كمال
update public.schools set supervisor_id='675c533c-c3d0-4102-a87d-e815115a973e' where id='2f4eb287-653c-45dd-b79e-066b418d29e5'; -- شهيد مصطفى حراجية ← عزالدين

-- علامة مشرف المادة كما كانت (لقطة private.v183_snap قبل التعديل)
update public.teacher_records tr set is_senior_teacher=(s.h='true') from private.v183_snap s
 where s.kind='flag_before' and s.k=tr.id::text and tr.is_senior_teacher is distinct from (s.h='true');

drop table public.school_supervisor_choice;
commit;
