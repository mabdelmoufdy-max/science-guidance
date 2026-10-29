-- استرجاع v216: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
update public.schools set approval_authority='school_manager' where stage='ثانوي' and approval_authority='admin';
drop function if exists public.coordinator_submit_school_for_approval(uuid,uuid,uuid);
-- الطلبات التي أُنشئت بمصدر المنسق تبقى في الجدول؛ إن أردت إعادة قيد المصدر القديم أعد مصدرها أولًا:
update public.school_submissions set entry_source='supervisor' where entry_source='stage_coordinator';
alter table public.school_submissions drop constraint if exists school_submissions_entry_source_chk;
alter table public.school_submissions add constraint school_submissions_entry_source_chk
  check (entry_source = any (array['school','supervisor','first_supervisor','admin']));
