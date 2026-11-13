-- استرجاع v369_portal_sup_mask_phone (2026-11-13)
-- يعيد دالة teacher_portal_sup_school إلى نصها قبل إخفاء الهاتف (يعتمد على private.v369_backup_functions — لا يُحذف).
do $$
declare d text;
begin
  select def into d from private.v369_backup_functions where name = 'teacher_portal_sup_school';
  if d is null then raise exception 'لا توجد نسخة احتياطية'; end if;
  execute d;
end $$;
