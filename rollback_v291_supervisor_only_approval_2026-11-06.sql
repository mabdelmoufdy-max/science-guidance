-- استرجاع v291 (الاعتماد لموجه المدرسة وحده) — يعتمد على private.v291_backup_school_authority و private.v291_backup_functions
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- عند النجاح: approval_authority يعود (school_manager:173, admin:13)، والدالتان كما كانتا قبل v291.
-- دالة الحافة supervisor-save-and-approve: أعد نشر edge/supervisor-save-and-approve.v3.ts.

alter table public.schools disable trigger trg_schools_row_version;
alter table public.schools disable trigger trg_schools_updated_at;
alter table public.schools disable trigger trg_schools_sup_group;
alter table public.schools disable trigger trg_enforce_school_identity;
alter table public.schools disable trigger trg_link_budget_reference_school;
alter table public.schools disable trigger trg_link_teacher_reference_school;

update public.schools s set approval_authority=b.approval_authority
  from private.v291_backup_school_authority b
 where b.id=s.id and s.approval_authority is distinct from b.approval_authority;

alter table public.schools enable trigger trg_schools_row_version;
alter table public.schools enable trigger trg_schools_updated_at;
alter table public.schools enable trigger trg_schools_sup_group;
alter table public.schools enable trigger trg_enforce_school_identity;
alter table public.schools enable trigger trg_link_budget_reference_school;
alter table public.schools enable trigger trg_link_teacher_reference_school;

alter table public.schools alter column approval_authority set default 'school_manager';

do $rb$
declare r record;
begin
  for r in select def from private.v291_backup_functions loop
    execute r.def;
  end loop;
end
$rb$;

alter function public.review_school_submission_atomic(uuid, text, text, bigint, text) security invoker;
