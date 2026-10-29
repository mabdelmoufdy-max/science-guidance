-- استرجاع: إعادة موجه الكيمياء للثانوي العام (9 مدارس) من شيماء محمد فرج إلى نوبي محمود عبدالله
update public.supervisor_school_subjects x
set supervisor_id=(select id from public.supervisors where full_name like 'نوبي محمود عبدالله%' limit 1)
where x.id in ('c3c66fb3-d5e8-49c4-b8f8-8a96d84097be','c68b00b8-ab9c-4627-8c25-5feecf894df0','a9a39cf5-6040-4b89-aa3d-3258540e7398','e8d40b4d-1741-4ca3-9982-796673347f40','15289d46-2c6d-4ebf-b93e-a103a1e7d5ea','316e7916-3d91-438e-abda-8ac9270c782c','d1df21be-d5cb-42f4-9309-c2c2f8d40cd4','bf9162d8-707a-4814-95c3-d37d56a0527a','897b56b0-4fae-4acb-bc5e-0c2166390833');
