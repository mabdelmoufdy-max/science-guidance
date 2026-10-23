-- Rollback: migration v172_coordinator_class_assignment
drop policy if exists teaching_coord_insert on public.teaching_assignments;
drop policy if exists teaching_coord_remove on public.teaching_assignments;
drop policy if exists submissions_coord_insert on public.school_submissions;
drop policy if exists submissions_coord_update on public.school_submissions;
