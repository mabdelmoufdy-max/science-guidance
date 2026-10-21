-- استرجاع: إعادة إجازة سلوى عبد المجيد محمد حسين (رعاية طفل) إلى «بانتظار التجديد» كما كانت قبل 2026-10-21
update public.teacher_long_leaves
set renewal_status='pending_renewal', decision_number=null, decision_date=null,
    effective_from=null, effective_to=null, approved_at=null,
    notes='مرحل من مراجعة بيانات بداية العام؛ يحسب ماليًا حتى وصول قرار التجديد.'
where id='09d39ed9-58cc-4376-8928-6f538a08f0fd';
