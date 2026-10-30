-- الخطوة ١ (2026-10-30، بطلب المستخدم): عُطِّل دور «الموجه الأول» المؤقت في حساب المالك (لم يُحذف). لإعادته:
update public.user_roles set is_active=true where profile_id='57e5112f-629b-479a-b7bd-8db465edcca3' and role='first_supervisor';
