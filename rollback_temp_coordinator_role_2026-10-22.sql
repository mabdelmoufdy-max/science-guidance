-- استرجاع: إزالة دور «منسق المرحلة» المؤقت من حساب المالك (أُضيف 2026-10-22 لتجربة لوحة القرارات v155).
delete from public.user_roles
where profile_id = '57e5112f-629b-479a-b7bd-8db465edcca3'
  and role = 'stage_coordinator';
