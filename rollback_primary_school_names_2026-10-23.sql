-- Rollback: primary school name spelling aligned to the primary budget PDF (2026-10-23)
-- Name changes are admin-only (enforce_school_identity), so run as admin or from SQL Editor with:
-- select set_config('request.headers','{"x-app-role":"admin"}',true); select set_config('request.jwt.claims','{"sub":"57e5112f-629b-479a-b7bd-8db465edcca3","role":"authenticated"}',true);
update public.schools set name='البخاتية الابتدائية المشتركة بالجمالية' where id='6b9b0a19-e3ab-4d40-bf19-745103b2fd64';
update public.schools set name='البخاتية الابتدائية تعليم اساسي بالجمالية' where id='999a9fa6-00ed-44a4-b03e-1b7f37e2e37e';
update public.schools set name='نجع الشيرات الابتدائية بجراجوس' where id='0573efcc-1f22-47d7-9935-49d3113e22f6';
