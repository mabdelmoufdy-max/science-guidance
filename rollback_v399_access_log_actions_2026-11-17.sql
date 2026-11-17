-- استرجاع v399: يحذف دالة القراءة الجديدة فقط (لا جداول ولا بيانات). تُشغَّل من SQL Editor لأنها تحوي أمر إزالة:
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- بعد التشغيل: الواجهة v399 تتجاوز الدالة الغائبة وتخفي عمود «الإجراءات» فقط (لا يتعطل «سجل الدخول»).
drop function if exists public.admin_access_actions(timestamptz, timestamptz);
