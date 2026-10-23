-- Rollback: migrations v171_coordinator_teacher_insert + v171b_coordinator_teacher_read_home_school
drop policy if exists teacher_records_coord_insert on public.teacher_records;
drop policy if exists teacher_records_coord_read on public.teacher_records;
