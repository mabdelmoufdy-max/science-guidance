-- استرجاع v292 (الاعتماد الأساسي لكل المدارس) — يعتمد على private.v292_backup_submissions و private.v292_backup_school_status
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- عند النجاح: الطلبات تعود (pending_manager_approval:108, in_progress:36, approved:2) وتُحذف الطلبات الأربعون الجديدة، وحالات المدارس كما كانت.
-- تنبيه: أي اعتماد/إعادة حدث بعد v292 سيُلغى بهذا الاسترجاع.
update public.school_submissions ss
   set status=b.status, approved_by=b.approved_by, approved_at=b.approved_at, return_reason=b.return_reason,
       intervention_reason=b.intervention_reason, last_changed_by=b.last_changed_by
  from private.v292_backup_submissions b
 where b.id=ss.id;
delete from public.school_submissions ss
 where not exists (select 1 from private.v292_backup_submissions b where b.id=ss.id);
update public.schools s set status=b.status
  from private.v292_backup_school_status b
 where b.id=s.id and s.status is distinct from b.status;
