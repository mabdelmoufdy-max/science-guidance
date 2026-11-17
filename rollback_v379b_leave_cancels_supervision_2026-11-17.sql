-- استرجاع v379b: يعيد نص دالة حفظ الإجازة السابق (قبل إلغاء الإشراف دون نقل) من النسخة المحفوظة؛ لا تحذف private.v379b_backup_functions قبل التشغيل.
do $do$ declare r record; begin
  for r in select def from private.v379b_backup_functions loop execute r.def; end loop;
end $do$;
-- إشراف مدرسة سارة: لإعادته لياسمين شغّل (بجلسة المدير) set_school_supervisor('09fb3307-ce8f-49d2-9f88-8d70f8aacdce', '89ab19b9-1466-4e2c-9a2f-875fe33229fe', '')؛ وقيمة الاختيار السابقة في private.v379_backup_state (kind='supervisor_choice_after_v379').
