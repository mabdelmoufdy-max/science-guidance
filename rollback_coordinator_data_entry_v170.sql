-- Rollback: migrations v170_coordinator_data_entry + v170b_coordinator_class_requirements + v170c_coordinator_class_requirements_delete + v170d_coordinator_approval_server_time
begin;
drop policy if exists csr_coord_insert on public.class_subject_requirements;
drop policy if exists csr_coord_update on public.class_subject_requirements;
drop policy if exists csr_coord_delete on public.class_subject_requirements;
drop policy if exists classes_coord_insert on public.school_classes;
drop policy if exists classes_coord_update on public.school_classes;
drop policy if exists classes_coord_delete on public.school_classes;
drop function if exists private.class_has_assignments(uuid);
drop table if exists public.coordinator_school_approvals;
drop function if exists private.stamp_coordinator_approval();
commit;
