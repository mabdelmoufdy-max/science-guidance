-- v264 (2026-11-04): حقل «التخصص على الكادر» في سجل المعلم + تعبئة أولية معتمدة من المستخدم
-- ابتدائي/إعدادي = علوم؛ ثانوي = نفس تخصص المعلم إن كان صريحًا (فيزياء أو كيمياء أو أحياء) ويُترك فارغًا إن غامض/فارغ.
-- لا يغيّر updated_at ولا row_version ولا sup_group (تُعطَّل مشغلات التحديث أثناء التعبئة فقط وتعاد فورًا).
-- الاسترجاع: rollback_v264_teacher_cadre_specialty_2026-11-04.sql

alter table public.teacher_records add column cadre_specialty text;
alter table public.teacher_records add constraint teacher_records_cadre_specialty_chk
  check (cadre_specialty is null or cadre_specialty in ('علوم','فيزياء','كيمياء','أحياء'));
-- صلاحية التعديل على مستوى العمود (الجدول يمنحها عمودًا عمودًا)؛ السياسات (RLS) كما هي
grant update (cadre_specialty) on public.teacher_records to authenticated;
comment on column public.teacher_records.cadre_specialty is 'التخصص على الكادر: علوم (ابتدائي/إعدادي) أو فيزياء/كيمياء/أحياء (ثانوي). v264';

-- نسخة احتياطية لما سيُعبَّأ (للاسترجاع الانتقائي؛ لا تُحذف)
create table private.v264_backup_prefill(
  teacher_id uuid primary key,
  value text not null,
  rule text not null,
  prefilled_at timestamptz not null default now()
);
insert into private.v264_backup_prefill(teacher_id,value,rule)
select id,value,rule from (
  select tr.id,
    case when s.stage in ('ابتدائي','إعدادي') then 'علوم'
         when (tr.specialty ~ 'فيزي|طبيع') and not (tr.specialty ~ 'كيمي|كمياء') and not (tr.specialty ~ 'حياء|بيولوج') then 'فيزياء'
         when (tr.specialty ~ 'كيمي|كمياء') and not (tr.specialty ~ 'فيزي|طبيع') and not (tr.specialty ~ 'حياء|بيولوج') then 'كيمياء'
         when (tr.specialty ~ 'حياء|بيولوج') and not (tr.specialty ~ 'فيزي|طبيع') and not (tr.specialty ~ 'كيمي|كمياء') then 'أحياء' end as value,
    case when s.stage in ('ابتدائي','إعدادي') then 'stage_default' else 'specialty_explicit' end as rule
  from public.teacher_records tr
  join public.schools s on s.id = tr.home_school_id
  where tr.active and tr.cadre_specialty is null
    and (s.stage in ('ابتدائي','إعدادي') or s.stage like 'ثانوي%')
) q where value is not null;

-- تعبئة بلا مسّ بوقت التعديل/النسخة/سجل المراجعة (حتى لا تظهر المدارس المعتمدة «عُدّلت بعد الاعتماد»)
alter table public.teacher_records disable trigger trg_teacher_records_updated_at;
alter table public.teacher_records disable trigger trg_teacher_records_row_version;
alter table public.teacher_records disable trigger trg_audit_teacher_record_changes;
update public.teacher_records tr set cadre_specialty = b.value
  from private.v264_backup_prefill b where b.teacher_id = tr.id;
alter table public.teacher_records enable trigger trg_teacher_records_updated_at;
alter table public.teacher_records enable trigger trg_teacher_records_row_version;
alter table public.teacher_records enable trigger trg_audit_teacher_record_changes;

-- سطر مراجعة واحد بدل مئات
insert into public.audit_log(actor_profile_id,actor_role,action,entity_type,entity_id,old_data,new_data)
values(null,null,'teacher_cadre_specialty_prefill','teacher_record',null,null,
  jsonb_build_object('migration','v264','prefilled',(select count(*) from private.v264_backup_prefill),
    'by_value',(select jsonb_object_agg(value,n) from (select value,count(*) n from private.v264_backup_prefill group by 1) x)));
