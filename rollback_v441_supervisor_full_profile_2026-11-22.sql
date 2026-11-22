-- استرجاع v441. صدّر بيانات supervisor_personal قبل الاسترجاع إذا جرى إدخال بيانات فعلية.
begin;
drop function public.save_supervisor_full_profile(uuid, jsonb);
drop function public.get_supervisor_profile(uuid);
drop table public.supervisor_personal;
commit;
