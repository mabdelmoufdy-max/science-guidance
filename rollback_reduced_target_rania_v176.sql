-- Rollback: v176 reduced weekly target (2026-10-23)
-- رانيا محمد عبد الباسط (الشعراني الاعدادية): نصاب 12 (إجازة نصف أجر) والإشراف نُقل إلى رانيا عبد الموجود محمد حسن.
begin;
update public.teacher_records set is_senior_teacher=false where id='a40f1a11-1ca0-4eec-acdd-3915c7137f28';
update public.teacher_records set is_senior_teacher=true, weekly_target_override=null where id='155fe4e3-dec0-4f27-b9e3-54f3a257e8e1';
do $$
declare d text := pg_get_viewdef('public.teacher_workload_summary'::regclass);
begin
  execute 'create or replace view public.teacher_workload_summary as ' ||
    replace(d, 'COALESCE((tr.weekly_target_override)::integer, wr.weekly_norm)', 'wr.weekly_norm');
end $$;
alter table public.teacher_records drop column weekly_target_override;
delete from public.supervision_declined where teacher_id='155fe4e3-dec0-4f27-b9e3-54f3a257e8e1' and school_id='caa808ac-b5ad-4283-ab8c-bfabeb7ed6fb';
commit;
