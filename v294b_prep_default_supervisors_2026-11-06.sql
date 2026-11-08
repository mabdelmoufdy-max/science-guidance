-- v294b (2026-11-06) بقرار المستخدم: «وبالنسبة للإعدادي اختار الأقدم مشرف أيضًا» — نفس قاعدة v294 للمرحلة الإعدادية.
-- لكل مدرسة إعدادية بها معلم ثابت وليس لها مشرف مادة (مدرستان: التحرير حراجية بنين، المنشية ع — مسجلتان بلا مشرف من قائمة الموجهين 2026-10-24):
-- يُختار الأقدم من الثابتين (ترتيب الأقدمية المعتمد في sync_school_senior_teacher، مع استبعاد المنتدب كليًا خارجها
-- ومن رفض الإشراف والإجازة المجددة) عبر public.set_school_supervisor بفاعل المالك/admin — نفس مسار الموجه، فيغيّره الموجه لاحقًا.
-- الاسترجاع: rollback_v294b_prep_default_supervisors_2026-11-06.sql (يعتمد على private.v294b_backup_* — لا تُحذف).
create table if not exists private.v294b_backup_targets as
  select s.id school_id from public.schools s
   where s.stage='إعدادي'
     and exists (select 1 from public.teacher_records tr where tr.home_school_id=s.id and tr.active and tr.work_type='permanent')
     and not exists (select 1 from public.teacher_records tr where tr.is_senior_teacher and tr.active and tr.home_school_id=s.id);
create table if not exists private.v294b_backup_choice as
  select c.* from public.school_supervisor_choice c where c.school_id in (select school_id from private.v294b_backup_targets);
create table if not exists private.v294b_backup_senior as
  select tr.id, tr.is_senior_teacher from public.teacher_records tr where tr.home_school_id in (select school_id from private.v294b_backup_targets);
do $m$
declare v_owner uuid := (select ur.profile_id from public.user_roles ur where ur.role='admin' and ur.is_active limit 1); r record; n int := 0;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.headers', '{"x-app-role":"admin"}', true);
  for r in
    with fulld as (select d.teacher_id, d.from_school_id from public.delegations d where d.active and d.delegation_type='full' and d.start_date<=current_date and (d.end_date is null or d.end_date>=current_date)),
    cand as (
      select t.school_id, tr.id teacher_id, row_number() over (partition by t.school_id order by public.teacher_job_grade_rank(tr.job_title) desc, tr.grade_acquired_date asc nulls last, tr.work_start_date asc nulls last, tr.appointment_date asc nulls last, tr.created_at asc, tr.id) rn
      from private.v294b_backup_targets t join public.teacher_records tr on tr.home_school_id=t.school_id and tr.active and tr.work_type='permanent'
      where not exists (select 1 from fulld f where f.teacher_id=tr.id and f.from_school_id=t.school_id)
        and not exists (select 1 from public.supervision_declined sd where sd.teacher_id=tr.id and sd.school_id=t.school_id)
        and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active where l.teacher_id=tr.id and l.renewal_status='renewed'))
    select school_id, teacher_id from cand where rn=1
  loop
    perform public.set_school_supervisor(r.school_id, r.teacher_id, null);
    n := n + 1;
  end loop;
  if n <> (select count(*) from private.v294b_backup_targets) then raise exception 'v294b: % schools set, expected %', n, (select count(*) from private.v294b_backup_targets); end if;
end
$m$;
