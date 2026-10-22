-- استرجاع: إعادة مشرف المادة في «التحرير حراجية بنين» إلى رانيه محمد القاضي بدل هبه مصطفى (2026-10-21)
update public.teacher_records set is_senior_teacher=(id='db47d11e-9123-4913-a453-ae74eaa99b19'), updated_at=now()
where id in ('db47d11e-9123-4913-a453-ae74eaa99b19','f189c3fe-8202-4b49-ac19-f4d41299ac45');
