-- استرجاع إلغاء «تغيير كلمة المرور الإجباري عند أول دخول» للموجهين الستة (2026-11-09)
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يعتمد على private.backup_must_change_pw_2026_11_09 (لا يُحذف).
-- عند النجاح: UPDATE 6 (أو أقل لمن غيّر كلمته بعد ذلك لا يتأثر لأن القيمة تعود true فقط)، ويعود البرنامج يطلب منهم تغيير كلمة المرور عند الدخول.
update public.profiles p set must_change_password=true
 where p.id in (select id from private.backup_must_change_pw_2026_11_09);
