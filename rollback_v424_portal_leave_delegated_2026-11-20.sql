-- استرجاع v424 (إجازة المنتدب من مشرف المدرسة المنتدب إليها). يُشغَّل من SQL Editor:
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يعيد الدوال الست إلى نسخة v423 من private.v424_backup_functions ثم يحذف دالة الأيام.
-- الإجازات المسجّلة لا تُمس. عند النجاح: «Success. No rows returned».
do $r$
declare f record;
begin
  for f in select fn, def from private.v424_backup_functions loop execute f.def; end loop;
end
$r$;
drop function if exists private.v424_off_days(uuid, uuid, date, date);
