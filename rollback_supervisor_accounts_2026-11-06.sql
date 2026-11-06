-- استرجاع حسابات الموجهين السبعة المنشأة 2026-11-06 (تعطيل لا حذف) + موقف فوزي احمد ابراهيم
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- عند النجاح: الموجهون السبعة بلا حساب مربوط (profile_id فارغ)، وحساباتهم موقوفة، وموقف فوزي «مكلف» كما كان.
with t(name) as (values ('حنان سيد حسن'),('كمال سعد محمد حمدان'),('عبدالهادي عبادي محمد عبدالرحيم'),('عزالدين محمد علي'),('رمضان محمد خليل احمد'),('موسى محمد عبدالقادر'),('فوزي احمد ابراهيم')),
 acc as (select s.id sup_id, s.profile_id from public.supervisors s join t on t.name=s.full_name where s.profile_id is not null)
select 1;
update public.user_roles set is_active=false where profile_id in (select s.profile_id from public.supervisors s where s.full_name in ('حنان سيد حسن','كمال سعد محمد حمدان','عبدالهادي عبادي محمد عبدالرحيم','عزالدين محمد علي','رمضان محمد خليل احمد','موسى محمد عبدالقادر','فوزي احمد ابراهيم') and s.profile_id is not null);
update public.profiles set is_active=false where id in (select s.profile_id from public.supervisors s where s.full_name in ('حنان سيد حسن','كمال سعد محمد حمدان','عبدالهادي عبادي محمد عبدالرحيم','عزالدين محمد علي','رمضان محمد خليل احمد','موسى محمد عبدالقادر','فوزي احمد ابراهيم') and s.profile_id is not null);
update auth.users set banned_until='infinity' where id in (select s.profile_id from public.supervisors s where s.full_name in ('حنان سيد حسن','كمال سعد محمد حمدان','عبدالهادي عبادي محمد عبدالرحيم','عزالدين محمد علي','رمضان محمد خليل احمد','موسى محمد عبدالقادر','فوزي احمد ابراهيم') and s.profile_id is not null);
update public.supervisors set profile_id=null where full_name in ('حنان سيد حسن','كمال سعد محمد حمدان','عبدالهادي عبادي محمد عبدالرحيم','عزالدين محمد علي','رمضان محمد خليل احمد','موسى محمد عبدالقادر','فوزي احمد ابراهيم');
update public.supervisors set assignment_status='مكلف' where full_name='فوزي احمد ابراهيم';
