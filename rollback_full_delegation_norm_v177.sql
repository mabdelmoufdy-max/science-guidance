-- Rollback v177: إلغاء «المنتدب كليًا يأخذ نصاب مرحلة المدرسة المنتدب إليها» (يعود النصاب لمرحلة المدرسة الأصلية دائمًا)
do $$
declare d text := pg_get_viewdef('public.teacher_workload_summary'::regclass);
begin
  d := regexp_replace(d, 'LEFT JOIN LATERAL \( SELECT ts_fd\.stage.*?\) fd ON \(true\)\s*', '', 's');
  d := replace(d, 'COALESCE(fd.stage, s.stage)', 's.stage');
  execute 'create or replace view public.teacher_workload_summary as ' || d;
end $$;
comment on view public.teacher_workload_summary is null;
