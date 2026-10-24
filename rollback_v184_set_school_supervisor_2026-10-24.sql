-- استرجاع v184: يزيل دالة set_school_supervisor والفهرس الفريد، ويعيد سطر الحماية (v183) في sync_school_senior_teacher.
-- اختيارات المشرفين المسجلة تبقى كما هي (جدول v183). شغّله قبل rollback_v183 إن احتجت الاثنين.
begin;
drop function if exists public.set_school_supervisor(uuid,uuid);
drop index if exists public.school_supervisor_choice_one_school_per_teacher;
do $mig$
declare d text; o text;
begin
  d := pg_get_functiondef('private.sync_school_senior_teacher'::regproc);
  o := d;
  d := replace(d, E'    and tr.id is distinct from v_winner\n      and tr.is_senior_teacher',E'    and tr.id is distinct from v_winner\n      and tr.is_senior_teacher');
  d := replace(d, E'  where tr.is_senior_teacher\n    and tr.id is distinct from v_winner\n',
    E'  where tr.is_senior_teacher\n    and tr.id is distinct from v_winner\n    and not exists (select 1 from public.school_supervisor_choice c3 where c3.teacher_id = tr.id and c3.school_id <> p_school_id)  -- v183\n');
  if d=o then raise exception 'sync: guard position not found'; end if;
  execute d;
end
$mig$;
commit;
