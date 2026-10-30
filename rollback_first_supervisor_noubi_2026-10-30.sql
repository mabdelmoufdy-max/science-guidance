-- استرجاع حساب الموجه الأول: نوبي محمود عبدالله (2026-10-30، بطلب المالك «أ نوبي هو الموجه الأول» ثم «أنشئه أنت» و«يبقى موجهًا للثانوي أيضًا»)
-- يُشغَّل من SQL Editor. يحذف الحساب ويفك ربط سجل الموجه؛ سجل الموجه وإسناد مرحلتي الثانوي يبقيان كما كانا قبل الحساب.
begin;
update public.supervisors set profile_id=null where id='ff31ff70-634a-4b5b-b435-34333a220c8d';
delete from public.user_roles where profile_id in (select id from public.profiles where civil_id=(select civil_id from public.supervisors where id='ff31ff70-634a-4b5b-b435-34333a220c8d'));
delete from public.profiles where civil_id=(select civil_id from public.supervisors where id='ff31ff70-634a-4b5b-b435-34333a220c8d');
delete from auth.users where email=(select civil_id from public.supervisors where id='ff31ff70-634a-4b5b-b435-34333a220c8d')||'@science-guidance.local';
commit;

-- (2026-10-30، لاحقًا بطلب المالك «طالما غير مسند له مدارس ثانوي لماذا يبقى موجه ثانوي»): صار الموجه الأول فقط —
-- عُطِّل دور supervisor وإسنادا مرحلتي الثانوي، وprofiles.role = first_supervisor. لإعادته موجهًا للثانوي أيضًا (بدل حذف الحساب):
-- update public.user_roles set is_active=true where role='supervisor' and profile_id=(select profile_id from public.supervisors where id='ff31ff70-634a-4b5b-b435-34333a220c8d');
-- update public.supervisor_stage_assignments set active=true where supervisor_id='ff31ff70-634a-4b5b-b435-34333a220c8d' and stage in ('ثانوي عام','ثانوي صناعي');
