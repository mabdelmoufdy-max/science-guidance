-- v229 (2026-10-30، بطلب المستخدم «نفذ ٣ب و٣ج»): تصغير get_reports_dataset بلا تغيير فيما يقرؤه البرنامج:
-- ٣ب: aug_ref/oct_ref (مرجع الميزانية، لا يقرؤه أي كود — يُمرَّر فقط في v97FilterDataset) صارا قائمتين فارغتين (المفتاحان باقيان).
-- ٣ج: حُذفت من صفوف school_teacher_rosters 4 حقول لا يرد اسمها في index.html: delegation_start_date, delegation_end_date, scope_auto_leadership_periods, global_auto_leadership_periods.
-- تجربة جافة: 17 مستخدمًا 0 فروق خارج المقصود؛ المدير 1861←1697 ك.ب. الاسترجاع: rollback_v229_reports_dataset_trim_unused_2026-10-30.sql
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
  if (length(d)-length(replace(d,a1,'')))/length(a1)<>1 or (length(d)-length(replace(d,a2,'')))/length(a2)<>1 or (length(d)-length(replace(d,a3,'')))/length(a3)<>1 then raise exception 'v229: anchor count <> 1'; end if;
  execute replace(replace(replace(d,a1,r1),a2,r2),a3,r3);
end $mig$;
