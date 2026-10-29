-- v220c (2026-10-29): إكمال إغلاق الموجه الأول (بطلب المستخدم «نفذها كلها»). النسخ الأصلية في private.v220c_backup — لا تُحذف.
do $$
declare d text;
begin
 -- إدارة الجداول المدرسية: بلا الموجه الأول
 d := replace(pg_get_functiondef('private.timetable_can_manage'::regproc), '''admin'',''first_supervisor'',', '''admin'',');
 execute d;
 -- نص رسالة الاستيراد الجماعي
 d := replace(pg_get_functiondef('public.bulk_import_science_guidance_atomic'::regproc), 'متاح لمدير النظام والموجه الأول فقط', 'متاح لمدير النظام فقط');
 execute d;
 -- اعتماد المنسق: الكتابة للمنسق ومدير النظام فقط (القراءة بسياسة coord_approvals_read بلا تغيير)
 execute $p$alter policy coord_approvals_write on public.coordinator_school_approvals
   using ((private.current_app_role() = ANY (ARRAY['admin'::app_role, 'stage_coordinator'::app_role])) AND private.can_access_stage(( SELECT s.stage FROM schools s WHERE (s.id = coordinator_school_approvals.school_id))))
   with check ((private.current_app_role() = ANY (ARRAY['admin'::app_role, 'stage_coordinator'::app_role])) AND (approved_by = auth.uid()) AND private.can_access_stage(( SELECT s.stage FROM schools s WHERE (s.id = coordinator_school_approvals.school_id))))$p$;
end $$;
