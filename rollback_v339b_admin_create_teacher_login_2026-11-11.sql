-- استرجاع v339b (2026-11-11): مدير النظام لا ينشئ حسابات دخول للمعلمين (كما قبل v339b).
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يعتمد على private.v339_backup_functions (لا يُحذف). عند النجاح: لا يُرجع صفوفًا.
-- الحسابات التي أُنشئت فعلًا تبقى (تعطيلها من «الحسابات»). ومعه أعد نشر edge/create-system-user.v11.ts.
do $r$
declare v_def text;
begin
  select def into v_def from private.v339_backup_functions where name = 'public.service_link_created_system_user_atomic';
  if v_def is null then raise exception 'النسخة الاحتياطية غير موجودة'; end if;
  execute v_def;
end
$r$;
