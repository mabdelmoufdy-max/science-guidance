-- استرجاع v339 (2026-11-11): إلغاء تغيير الرقم القومي من صفحة المعلم وإعادة مشغل المنع كما كان.
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يعتمد على private.v339_backup_functions (لا يُحذف).
-- عند النجاح: لا يُرجع صفوفًا؛ وبعده select to_regprocedure('public.admin_change_teacher_civil_id(uuid,text)') يعيد null.
-- ملاحظة: أي رقم قومي غُيِّر فعلًا لا يرجع تلقائيًا؛ القيم القديمة في audit_log (action='admin_change_teacher_civil_id')،
-- ولإرجاع رقم معلم قبل الاسترجاع: استدعِ الدالة نفسها بالرقم القديم من صفحة المعلم.

do $r$
declare v_def text;
begin
  select def into v_def from private.v339_backup_functions where name = 'public.enforce_civil_id_identity';
  if v_def is null then raise exception 'نسخة المشغل الاحتياطية غير موجودة'; end if;
  execute v_def;
end
$r$;

revoke all on function public.admin_change_teacher_civil_id(uuid, text) from authenticated;
drop function if exists public.admin_change_teacher_civil_id(uuid, text);
