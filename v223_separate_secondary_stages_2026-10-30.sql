-- v223 (2026-10-30، بطلب المستخدم): فصل «ثانوي عام» عن «ثانوي صناعي» مرحلتين مستقلتين في قاعدة البيانات.
-- النصاب واحد (نُسخت قواعد «ثانوي» للمرحلتين)، ومنسقو/موجهو «ثانوي» صاروا للمرحلتين. لكل مرحلة منهجها:
--   عام: الأول علوم متكاملة؛ الثاني/الثالث فيزياء وكيمياء وأحياء (نفس معرّفات المواد السابقة).
--   صناعي: الأول فيزياء وكيمياء (معرّفاتهما السابقة IND)؛ الثاني/الثالث فيزياء (مادتان جديدتان)، + «علوم متكاملة» للأول غير نشطة
--   (لسطرين قديمين بصفر حصص). متطلبات وإسنادات الصناعي أُعيد ربطها بمواد مرحلته (نفس الاسم والصف والحصص).
-- النسخ الاحتياطية: private.v223_backup_* (لا تُحذف). الاسترجاع: rollback_v223_separate_secondary_stages_2026-10-30.sql
create table if not exists private.v223_backup_schools as select id, stage, school_type from public.schools where stage='ثانوي';
create table if not exists private.v223_backup_classes as select id, school_id, stage from public.school_classes where stage='ثانوي';
create table if not exists private.v223_backup_reqs as select r.id, r.class_id, r.subject_id from public.class_subject_requirements r join public.school_classes c on c.id=r.class_id where c.stage='ثانوي';
create table if not exists private.v223_backup_assign as select a.id, a.class_id, a.subject_id from public.teaching_assignments a join public.school_classes c on c.id=a.class_id where c.stage='ثانوي';
create table if not exists private.v223_backup_subjects as select * from public.curriculum_subjects where stage='ثانوي';
create table if not exists private.v223_backup_rules as select * from public.workload_rules where stage='ثانوي';
create table if not exists private.v223_backup_sca as select * from public.stage_coordinator_assignments where stage='ثانوي';
create table if not exists private.v223_backup_ssa as select * from public.supervisor_stage_assignments where stage='ثانوي';
create table if not exists private.v223_backup_defs as
 select 'function'::text kind, p.oid::regprocedure::text name, pg_get_functiondef(p.oid) def from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.prokind='f' and p.proname in ('validate_school_class_invariants','teacher_workload_target','secondary_supervisor_census','tp_stage_key','service_link_created_system_user_atomic','bulk_import_science_guidance_atomic')
 union all select 'view','public.teacher_workload_summary', pg_get_viewdef('public.teacher_workload_summary'::regclass)
 union all select 'constraint', conrelid::regclass::text||'|'||conname, pg_get_constraintdef(oid) from pg_constraint where conname in ('stage_coordinator_assignments_stage_check','supervisor_stage_assignments_stage_check');

-- 1) قيود المرحلة لإسناد المنسقين والموجهين (يبقى «ثانوي» مقبولًا للسجلات القديمة المعطلة)
alter table public.stage_coordinator_assignments drop constraint stage_coordinator_assignments_stage_check,
 add constraint stage_coordinator_assignments_stage_check check (stage = any (array['ابتدائي'::text,'إعدادي'::text,'ثانوي'::text,'ثانوي عام'::text,'ثانوي صناعي'::text]));
alter table public.supervisor_stage_assignments drop constraint supervisor_stage_assignments_stage_check,
 add constraint supervisor_stage_assignments_stage_check check (stage = any (array['ابتدائي'::text,'إعدادي'::text,'ثانوي'::text,'ثانوي عام'::text,'ثانوي صناعي'::text]));

-- 2) الدوال والعرض: قوائم المراحل والمقارنات النصية بـ«ثانوي»
do $m$
declare d text; o text; r record;
begin
 for r in select * from (values
   ('private.teacher_workload_target', $a$('ابتدائي','إعدادي','ثانوي')$a$, $b$('ابتدائي','إعدادي','ثانوي','ثانوي عام','ثانوي صناعي')$b$),
   ('public.validate_school_class_invariants', $a$new.stage='ثانوي'$a$, $b$new.stage in ('ثانوي','ثانوي عام','ثانوي صناعي')$b$),
   ('public.secondary_supervisor_census', $a$.stage='ثانوي'$a$, $b$.stage like 'ثانوي%'$b$),
   ('private.tp_stage_key', $a$when p_stage = 'ثانوي' and p_type$a$, $b$when p_stage = 'ثانوي صناعي' then 'sec_industrial' when p_stage = 'ثانوي عام' then 'sec_general' when p_stage = 'ثانوي' and p_type$b$),
   ('public.service_link_created_system_user_atomic', $a$('ابتدائي','إعدادي','ثانوي')$a$, $b$('ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي')$b$),
   ('public.bulk_import_science_guidance_atomic', $a$('ابتدائي','إعدادي','ثانوي')$a$, $b$('ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي')$b$)
 ) v(fn, a, b) loop
   select pg_get_functiondef(p.oid) into o from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname||'.'||p.proname)=r.fn and p.prokind='f';
   if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname||'.'||p.proname)=r.fn)<>1 then raise exception 'v223: عدد غير متوقع من الدوال %', r.fn; end if;
   if o is null then raise exception 'v223: الدالة غير موجودة %', r.fn; end if;
   d := replace(o, r.a, r.b);
   if d = o then raise exception 'v223: لم يتغير نص %', r.fn; end if;
   execute d;
 end loop;
 o := pg_get_viewdef('public.teacher_workload_summary'::regclass);
 d := replace(o, $a$ARRAY['ابتدائي'::text, 'إعدادي'::text, 'ثانوي'::text]$a$, $b$ARRAY['ابتدائي'::text, 'إعدادي'::text, 'ثانوي'::text, 'ثانوي عام'::text, 'ثانوي صناعي'::text]$b$);
 if d = o then raise exception 'v223: لم يتغير العرض'; end if;
 execute 'create or replace view public.teacher_workload_summary as '||d;
end $m$;

-- 3) قواعد النصاب: نفس أنصبة «ثانوي» للمرحلتين، وتعطيل سطور «ثانوي»
insert into public.workload_rules(job_title,stage,weekly_norm,effective_from,effective_to,source_reference,active)
 select w.job_title, st, w.weekly_norm, w.effective_from, w.effective_to, w.source_reference, w.active
 from public.workload_rules w cross join unnest(array['ثانوي عام','ثانوي صناعي']) st where w.stage='ثانوي';
update public.workload_rules set active=false where stage='ثانوي';

-- 4) المنسقون والموجهون: إسناد «ثانوي» صار للمرحلتين
insert into public.stage_coordinator_assignments(supervisor_id,stage,active,assigned_by,assigned_at)
 select a.supervisor_id, st, a.active, a.assigned_by, now() from public.stage_coordinator_assignments a cross join unnest(array['ثانوي عام','ثانوي صناعي']) st where a.stage='ثانوي'
 on conflict (supervisor_id, stage) do nothing;
update public.stage_coordinator_assignments set active=false where stage='ثانوي';
insert into public.supervisor_stage_assignments(supervisor_id,stage,active,created_at)
 select a.supervisor_id, st, a.active, now() from public.supervisor_stage_assignments a cross join unnest(array['ثانوي عام','ثانوي صناعي']) st where a.stage='ثانوي'
 on conflict (supervisor_id, stage) do nothing;
update public.supervisor_stage_assignments set active=false where stage='ثانوي';

-- 5) المنهج: لكل مرحلة موادها
update public.curriculum_subjects set stage='ثانوي صناعي' where stage='ثانوي' and subject_code in ('SCI-S1-IND-PHYS','SCI-S1-IND-CHEM');
update public.curriculum_subjects set stage='ثانوي عام' where stage='ثانوي';
insert into public.curriculum_subjects(stage,grade,subject_name,subject_code,subject_group,active,sort_order)
 select 'ثانوي صناعي', grade, subject_name, regexp_replace(subject_code,'^SCI-(S[0-9])-','SCI-\1-IND-'), subject_group, subject_code<>'SCI-S1-INTEGRATED', sort_order
 from public.curriculum_subjects where stage='ثانوي عام' and subject_code in ('SCI-S2-PHYS','SCI-S3-PHYS','SCI-S1-INTEGRATED');

-- 6) المدارس والفصول وإعادة ربط مواد الصناعي (بلا مشغلات: لا إعادة توليد للمتطلبات ولا تغيير حصص)
set local session_replication_role = replica;
update public.schools set stage=school_type where stage='ثانوي' and school_type in ('ثانوي عام','ثانوي صناعي');
update public.school_classes c set stage=s.stage from public.schools s where s.id=c.school_id and c.stage='ثانوي';
update public.class_subject_requirements r set subject_id=n.id
 from public.school_classes c, public.curriculum_subjects o, public.curriculum_subjects n
 where c.id=r.class_id and c.stage='ثانوي صناعي' and o.id=r.subject_id and o.stage='ثانوي عام'
   and n.stage='ثانوي صناعي' and n.grade=o.grade and n.subject_name=o.subject_name;
update public.teaching_assignments a set subject_id=n.id
 from public.school_classes c, public.curriculum_subjects o, public.curriculum_subjects n
 where c.id=a.class_id and c.stage='ثانوي صناعي' and o.id=a.subject_id and o.stage='ثانوي عام'
   and n.stage='ثانوي صناعي' and n.grade=o.grade and n.subject_name=o.subject_name;
set local session_replication_role = origin;
