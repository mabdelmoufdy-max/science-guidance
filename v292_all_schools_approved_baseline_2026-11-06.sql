-- v292 (2026-11-06) بطلب المستخدم: «نحن الآن في مرحلة بناء للبرنامج — حوّل كل المدارس لمعتمدة».
-- اعتماد أساسي لكل المدارس (الفصل الدراسي الحالي): 144 طلبًا قائمًا (108 بانتظار + 36 جاري) ← معتمد، و40 مدرسة بلا طلب ← طلب معتمد جديد.
-- المعتمد = مدير النظام (المالك)، entry_source='admin' للجديدة، وسبب التدخل موثق. المشغلات تعمل (سطر audit لكل مدرسة، ومزامنة schools.status).
-- الاسترجاع: rollback_v292_all_schools_approved_baseline_2026-11-06.sql (يعتمد على private.v292_backup_* — لا تُحذف).
create table if not exists private.v292_backup_submissions as select * from public.school_submissions;
create table if not exists private.v292_backup_school_status as select id, status from public.schools;
do $m$
declare v_owner uuid := (select ur.profile_id from public.user_roles ur where ur.role='admin' and ur.is_active limit 1);
        v_term uuid; v_year uuid; v_reason text := 'اعتماد أساسي لكل المدارس — مرحلة البناء (بقرار المستخدم 2026-11-06)';
begin
  select id, academic_year_id into v_term, v_year from public.terms where is_active limit 1;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.headers', '{"x-app-role":"admin"}', true);
  update public.school_submissions
     set status='approved', approved_by=v_owner, approved_at=now(), return_reason=null,
         intervention_reason=v_reason, last_changed_by=v_owner
   where term_id=v_term and status<>'approved';
  insert into public.school_submissions(school_id,academic_year_id,term_id,status,submitted_by,submitted_at,approved_by,approved_at,entry_source,intervention_reason,last_changed_by)
  select s.id, v_year, v_term, 'approved', v_owner, now(), v_owner, now(), 'admin', v_reason, v_owner
    from public.schools s
   where not exists (select 1 from public.school_submissions ss where ss.school_id=s.id and ss.term_id=v_term);
end
$m$;
