-- استرجاع 2026-10-25: موجه فوزي احمد ابراهيم (600cd4f8…) ومدارسه الثمانية، وإلغاء انتداب مصنع السكر، وأسماء الحسابات.
update public.schools set supervisor_id=null where supervisor_id='600cd4f8-339e-46be-b9eb-9366e1ce6a58';
-- المدرستان اللتان كانتا على سجل شيماء الخاص (باسم فوزي) قبل التعديل:
update public.schools set supervisor_id='2572cdbd-2294-4616-acc2-38dfff0e085f' where id in ('a427709e-4f09-40be-aebc-a8fb2f93a01c','a328ba9e-c647-43bb-b6b7-5a0f96ad83a1');
-- المدارس الستة الأخرى كانت: النصر بالجزيرة/جزيرة مطيرة ع/الجديدة = عزالدين (675c533c…)، قوص المهني/المعري ع/العليقات الاعدادية = كمال (bacb6309…)
update public.schools set supervisor_id='675c533c-c3d0-4102-a87d-e815115a973e' where id in ('f753ce1d-b82f-43f9-b11f-78be242cace8','3fcfd82a-0978-41f9-b0f0-1f991bc8dcb2','34fb1ae0-3f34-433b-8a1d-9b08066135ce');
update public.schools set supervisor_id='bacb6309-6181-4afb-b005-c390df6295c5' where id in ('db948157-15dc-486b-94e3-b6193faacff5','966b909d-1901-44e1-8f1d-ea6e22b952e1','bffb833b-311e-46b8-9b5f-3e85b1af06c2');
update public.delegations set active=true where id='9b5ada91-bae8-4c5c-95e3-f57e49c23cf9';
update public.supervisor_stage_assignments set active=false where supervisor_id='600cd4f8-339e-46be-b9eb-9366e1ce6a58';
update public.supervisors set active=false where id='600cd4f8-339e-46be-b9eb-9366e1ce6a58';
