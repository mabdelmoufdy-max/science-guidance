-- v213 (طُبّق 2026-10-28): إضافة مجموعة من بوابة المنسق كانت تتجاوز مهلة الاستعلام (إدراج ~6.5 ث بصلاحية المنسق) لأن مشغّلي توليد متطلبات الفصل ينفذان بصلاحية المستدعي فتُقيَّم RLS لكل أمر. صارا SECURITY DEFINER (يعملان فقط على الفصل الجديد المسموح بإدراجه): الإدراج 103ms.
alter function public.seed_class_curriculum_subjects() security definer;
alter function public.sync_class_curriculum_requirements() security definer;
