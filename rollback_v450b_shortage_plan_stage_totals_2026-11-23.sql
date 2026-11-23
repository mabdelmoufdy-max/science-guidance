-- يلغي دالة القراءة التجميعية لتقرير «بيان خطة الإدارة» (لا يمس أي بيانات)
drop function if exists public.shortage_plan_stage_totals();
