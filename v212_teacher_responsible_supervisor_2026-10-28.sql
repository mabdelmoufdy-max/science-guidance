-- v212: الموجه المسؤول عن المعلم (يختاره المنسق من قائمة) — جدول جديد بلا مساس بأي جدول قائم
-- شغّله من SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
create table if not exists public.teacher_responsible_supervisor (
  teacher_id uuid primary key references public.teacher_records(id) on delete cascade,
  supervisor_id uuid references public.supervisors(id) on delete set null,
  set_by uuid default auth.uid(),
  updated_at timestamptz not null default now()
);
alter table public.teacher_responsible_supervisor enable row level security;
revoke all on public.teacher_responsible_supervisor from anon;
grant select, insert, update on public.teacher_responsible_supervisor to authenticated;
grant all on public.teacher_responsible_supervisor to service_role;

create policy trs_read on public.teacher_responsible_supervisor for select to authenticated using (
  private.current_app_role() in ('admin','first_supervisor')
  or (private.current_app_role() in ('stage_coordinator','supervisor','school_manager','senior_teacher') and private.can_access_teacher(teacher_id))
);
create policy trs_insert on public.teacher_responsible_supervisor for insert to authenticated with check (
  private.current_app_role() in ('admin','first_supervisor')
  or (private.current_app_role()='stage_coordinator' and private.can_access_teacher(teacher_id))
);
create policy trs_update on public.teacher_responsible_supervisor for update to authenticated using (
  private.current_app_role() in ('admin','first_supervisor')
  or (private.current_app_role()='stage_coordinator' and private.can_access_teacher(teacher_id))
) with check (
  private.current_app_role() in ('admin','first_supervisor')
  or (private.current_app_role()='stage_coordinator' and private.can_access_teacher(teacher_id))
);

create or replace function private.trs_touch() returns trigger language plpgsql set search_path to 'pg_catalog','public','pg_temp' as $$
begin new.updated_at:=now(); new.set_by:=auth.uid(); return new; end $$;
create trigger trg_trs_touch before insert or update on public.teacher_responsible_supervisor for each row execute function private.trs_touch();
