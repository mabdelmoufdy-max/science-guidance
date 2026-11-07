-- يعيد دخول مشرف المدرسة إلى اشتراط كود المعلم (إن كان له كود مسجّل).
-- يعتمد على private.v304_backup_functions — لا تُحذف.
do $$
declare r record;
begin
  for r in select def from private.v304_backup_functions loop
    execute r.def;
  end loop;
end $$;
-- (اختياري) الدالة الجديدة private.tp_sup_view_check تبقى بلا استعمال.
