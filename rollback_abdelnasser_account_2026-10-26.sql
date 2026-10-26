-- استرجاع حساب عبدالناصر محمد سعيد (تعطيل لا حذف): يفصل الحساب عن سجل الموجه ويوقفه
update public.user_roles set is_active=false where profile_id='061b917b-fc28-4321-b33f-bade65bc9637';
update public.profiles set is_active=false where id='061b917b-fc28-4321-b33f-bade65bc9637';
update public.supervisors set profile_id=null where id='08da6b26-6a45-4256-984b-ed37daa3e89e' and profile_id='061b917b-fc28-4321-b33f-bade65bc9637';
update auth.users set banned_until='infinity' where id='061b917b-fc28-4321-b33f-bade65bc9637';
