-- v231 (2026-10-30، بطلب المستخدم «نفذ الخطوات ١ و٢ و٣»، الخطوة ٢): سحب كل صلاحيات المستخدم غير المسجّل (anon) من العرض teacher_workload_summary.
-- كانت له كل الصلاحيات (SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER)؛ القراءة كانت تُرفض فعليًا (permission denied لـ current_app_role) فلا أثر على أي شاشة.
-- الاسترجاع: rollback_v231_revoke_anon_teacher_workload_summary_2026-10-30.sql
revoke all on public.teacher_workload_summary from anon;
