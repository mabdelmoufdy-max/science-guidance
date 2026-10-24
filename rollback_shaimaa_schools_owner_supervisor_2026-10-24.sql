-- استرجاع (2026-10-24): إعادة مدارس شيماء محمد فرج محمد العشر إلى سجل الموجه المربوط بحساب المالك، وإعادة تفعيل دور «الموجه» للمالك.
update public.schools set supervisor_id='54161bac-29ed-4276-a0e0-a45b23ca4b8e' where id in (
 '480c84d4-ceff-4996-9888-6855cdd20e64','385a3919-63e4-49fc-bb30-effb8a74388d','a427709e-4f09-40be-aebc-a8fb2f93a01c','fc392803-3675-4aa9-a351-0a6103a3eda3','071c805a-6f46-4e29-9e1a-011fb4103239',
 '787d8b12-5e4e-4d3b-a6c8-c1a453a14257','ab8f8c92-6332-4e8d-a68d-4cdd964117f7','2f4eb287-653c-45dd-b79e-066b418d29e5','e3c64100-4294-4b79-b5a0-839174231250','a33d9d52-4dd9-4579-86e5-248f5c92d76e');
update public.user_roles set is_active=true where profile_id='57e5112f-629b-479a-b7bd-8db465edcca3' and role='supervisor';
