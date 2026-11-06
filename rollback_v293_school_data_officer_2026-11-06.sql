-- استرجاع v293 (مسؤول بيانات المدرسة + منع التعديل لغير المكلّف في «حساب المدرسة»)
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- عند النجاح: لا يبقى مشغل trg_v293_school_officer_gate (0)، وتعود مزامنة الدخول كما كانت (مشرف المادة فقط)،
-- ويعود كل من له دور «مشرف المادة» يعدّل بيانات مدرسته. تُفقد اختيارات «مسؤول البيانات» اليدوية (انسخ الجدول قبلها إن أردت).
do $rb$
declare t text;
begin
  foreach t in array array['school_classes','class_subject_requirements','teaching_assignments','teacher_records',
                           'teacher_school_assignments','delegations','school_submissions','teacher_paid_shortage_allocations',
                           'school_timetable_config','teacher_timetable_slots','data_completion_changes'] loop
    execute format('drop trigger if exists trg_v293_school_officer_gate on public.%I', t);
  end loop;
  execute (select def from private.v293_backup_functions where fn='public.sync_teacher_record_user_roles');
end
$rb$;
drop function if exists private.school_officer_write_gate();
drop function if exists public.set_school_data_officer(uuid, uuid);
drop function if exists public.school_data_officer_info(uuid);
drop function if exists private.sync_school_login_role(uuid);
drop function if exists private.is_school_data_officer(uuid);
drop function if exists private.school_data_officer_teacher(uuid);
drop table if exists public.school_data_officer;
