-- استرجاع v229: يعيد مرجع الميزانية (aug_ref/oct_ref) والحقول الأربعة إلى get_reports_dataset (عكس الاستبدال).
do $mig$
declare d text;
  a1 text := E'''aug_ref'',coalesce((\n    select jsonb_agg(to_jsonb(b) order by b.source_row_no)\n    from public.school_budget_reference_summary b\n    where b.snapshot_key=''aug_2026_preparatory_qous''\n  ),''[]''::jsonb),';
  r1 text := E'''aug_ref'',''[]''::jsonb,  -- v229: لا يقرؤها البرنامج (شاشة الميزانية حُذفت v157)';
  a2 text := E'''oct_ref'',coalesce((\n    select jsonb_agg(to_jsonb(b) order by b.source_row_no)\n    from public.school_budget_reference_summary b\n    where b.snapshot_key=''oct_2026_preparatory_qous''\n  ),''[]''::jsonb),';
  r2 text := E'''oct_ref'',''[]''::jsonb,  -- v229';
  a3 text := 'select jsonb_agg(sr.row_data order by';
  r3 text := 'select jsonb_agg((sr.row_data - array[''delegation_start_date'',''delegation_end_date'',''scope_auto_leadership_periods'',''global_auto_leadership_periods'']) order by';
begin
  d := pg_get_functiondef('public.get_reports_dataset(uuid)'::regprocedure);
  if (length(d)-length(replace(d,r1,'')))/length(r1)<>1 or (length(d)-length(replace(d,r2,'')))/length(r2)<>1 or (length(d)-length(replace(d,r3,'')))/length(r3)<>1 then raise exception 'rollback v229: anchor count <> 1'; end if;
  execute replace(replace(replace(d,r1,a1),r2,a2),r3,a3);
end $mig$;
