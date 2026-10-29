-- v214 (طُبّق 2026-10-28): تسريع تعديل حصص مواد الفصل بصلاحية المنسق (1265ms ← 475ms لكل مادة): أربعة مشغّلات على class_subject_requirements صارت SECURITY DEFINER (تعمل على صف الفصل نفسه فقط). أثر جانبي مفيد: science_periods يُحدَّث الآن أيضًا عند تعديل المنسق (كان تحديثه محجوبًا بـRLS).
alter function public.refresh_class_science_periods() security definer;
alter function public.sync_class_science_periods() security definer;
alter function public.validate_class_subject_requirement() security definer;
alter function public.validate_class_subject_requirement_invariants() security definer;
