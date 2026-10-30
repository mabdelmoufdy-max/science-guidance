-- استرجاع حساب الموجه الأول: نوبي محمود عبدالله (2026-10-30، بطلب المالك «أ نوبي هو الموجه الأول» ثم «أنشئه أنت» و«يبقى موجهًا للثانوي أيضًا»)
-- يُشغَّل من SQL Editor. يحذف الحساب ويفك ربط سجل الموجه؛ سجل الموجه وإسناد مرحلتي الثانوي يبقيان كما كانا قبل الحساب.
begin;
update public.supervisors set profile_id=null where id='ff31ff70-634a-4b5b-b435-34333a220c8d';
delete from public.user_roles where profile_id in (select id from public.profiles where civil_id=(select civil_id from public.supervisors where id='ff31ff70-634a-4b5b-b435-34333a220c8d'));
delete from public.profiles where civil_id=(select civil_id from public.supervisors where id='ff31ff70-634a-4b5b-b435-34333a220c8d');
delete from auth.users where email=(select civil_id from public.supervisors where id='ff31ff70-634a-4b5b-b435-34333a220c8d')||'@science-guidance.local';
commit;
