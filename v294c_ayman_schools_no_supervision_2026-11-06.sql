-- v294c (2026-11-06) بقرار المستخدم «أ» بعد رسالة الموجه ايمن وهيب: 11 مدرسة ابتدائية بلا إشراف
-- (5: «لا يكفي النصاب لعمل المشرف»؛ 6: «المعلم الوحيد بالمدرسة»)، مع إبقاء المعلم نفسه «مسؤول بيانات» بلا حصتي إشراف.
-- مدرستان (الشهداء بالعليقات، الصديق ابوبكر بحجازة قبلي) كان بركات قد ألغى إشرافهما بنفسه 2026-11-06 23:21/23:25 — يُترك سجله ويُعيَّن مسؤول البيانات فقط.
-- الاسترجاع: rollback_v294c_ayman_schools_no_supervision_2026-11-06.sql (يعتمد على private.v294c_backup_*).
create table if not exists private.v294c_backup_targets as
  select s.id school_id, s.name from public.schools s
   where s.stage='ابتدائي' and s.name in ('ابن دقيق العيد الابتدائية بقوص','الجمالية الابتدائية المشتركة','الجمالية الابتدائية تعليم اساسي','الخرانقة الابتدائية القديمة','الصديق ابوبكر الابتدائية بحجازة قبلي',
    'الشهداء الابتدائية بالعليقات','العصارة الابتدائية بالجمالية','السلام الابتدائية بالعصارة','شنهور الابتدائية','كاثوليك حجازة','كاثوليك جراجوس');
create table if not exists private.v294c_backup_choice as
  select c.* from public.school_supervisor_choice c where c.school_id in (select school_id from private.v294c_backup_targets);
create table if not exists private.v294c_backup_officer as
  select o.* from public.school_data_officer o where o.school_id in (select school_id from private.v294c_backup_targets);
do $m$
declare v_owner uuid := (select ur.profile_id from public.user_roles ur where ur.role='admin' and ur.is_active limit 1); r record;
begin
  if (select count(*) from private.v294c_backup_targets)<>11 then raise exception 'v294c: expected 11 schools'; end if;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.headers', '{"x-app-role":"admin"}', true);
  for r in
    select t.school_id, c.teacher_id choice_teacher,
      coalesce(c.teacher_id, (select tr.id from public.teacher_records tr where tr.home_school_id=t.school_id and tr.active and tr.work_type='permanent'
         order by public.teacher_job_grade_rank(tr.job_title) desc, tr.grade_acquired_date asc nulls last, tr.work_start_date asc nulls last, tr.appointment_date asc nulls last, tr.created_at asc, tr.id limit 1)) teacher_id,
      case when t.name in ('ابن دقيق العيد الابتدائية بقوص','الجمالية الابتدائية المشتركة','الجمالية الابتدائية تعليم اساسي','الخرانقة الابتدائية القديمة','الصديق ابوبكر الابتدائية بحجازة قبلي')
        then 'بقرار الموجه (ايمن وهيب): لا يكفي النصاب لعمل المشرف' else 'بقرار الموجه (ايمن وهيب): المعلم الوحيد بالمدرسة' end note
    from private.v294c_backup_targets t left join public.school_supervisor_choice c on c.school_id=t.school_id and c.grp=''
  loop
    if r.teacher_id is null then raise exception 'v294c: no permanent teacher for %', r.school_id; end if;
    perform public.set_school_data_officer(r.school_id, r.teacher_id);
    if r.choice_teacher is not null then
      perform public.set_school_supervisor(r.school_id, null, null);
      update public.school_supervisor_choice set note=r.note where school_id=r.school_id and grp='';
    end if;
  end loop;
end
$m$;
