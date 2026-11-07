-- يلغي إدخال المعلم لجدوله من البوابة (v305). يعتمد على private.v305_backup_objects — لا يُحذف.
-- 1) دالتا البوابة
drop function if exists public.teacher_portal_timetable_get(text,text);
drop function if exists public.teacher_portal_timetable_save(text,text,jsonb);
-- 2) المشغلان كما كانا
do $$ declare r record; begin
  for r in select def from private.v305_backup_objects where k in ('validate_timetable_slot','validate_timetable_config') loop execute r.def; end loop;
end $$;
-- 3) الإعدادات: الصفوف التي أُنشئت (غير الموجودة في النسخة) تُحذف، والموجودة تعود لما كانت عليه
set local session_replication_role = replica;
delete from public.school_timetable_config c
 where c.term_id=(select term_id from private.tp_active())
   and not exists (select 1 from private.v305_backup_objects b where b.k='config_row:'||c.school_id::text||':'||c.term_id::text);
update public.school_timetable_config c set
  operating_days=(b.def::jsonb->>'operating_days')::text::smallint[] ,
  periods_per_day=(b.def::jsonb->>'periods_per_day')::smallint
 from private.v305_backup_objects b where b.k='config_row:'||c.school_id::text||':'||c.term_id::text;
set local session_replication_role = origin;
-- 4) (اختياري، بعد التأكد أن كل الحصص created_by غير فارغ) alter table public.teacher_timetable_slots alter column created_by set not null;
-- 5) alter table public.teacher_portal_settings drop column timetable_open;
