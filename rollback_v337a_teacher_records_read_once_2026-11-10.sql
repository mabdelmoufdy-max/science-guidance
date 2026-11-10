-- استرجاع v337a (2026-11-10): يعيد سياستي قراءة teacher_records إلى نصهما الأصلي (فحص لكل صف).
alter policy teacher_records_read on public.teacher_records
  using ((profile_id = ( SELECT auth.uid() AS uid)) OR private.can_access_teacher(id));
alter policy teacher_records_coord_read on public.teacher_records
  using ((( SELECT current_app_role() AS current_app_role) = 'stage_coordinator'::app_role) AND can_access_school(home_school_id));
