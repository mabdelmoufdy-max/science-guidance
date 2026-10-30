-- استرجاع v223: يعيد مرحلة «ثانوي» الواحدة من private.v223_backup_* (شغّله كاملًا مرة واحدة).
set local session_replication_role = replica;
update public.teaching_assignments a set subject_id=b.subject_id from private.v223_backup_assign b where b.id=a.id and a.subject_id<>b.subject_id;
update public.class_subject_requirements r set subject_id=b.subject_id from private.v223_backup_reqs b where b.id=r.id and r.subject_id<>b.subject_id;
update public.school_classes c set stage=b.stage from private.v223_backup_classes b where b.id=c.id;
update public.schools s set stage=b.stage from private.v223_backup_schools b where b.id=s.id;
set local session_replication_role = origin;
-- المواد: إعادة «ثانوي» للمعرّفات الأصلية، وتعطيل المواد الجديدة للصناعي (لا يُحذف شيء)
update public.curriculum_subjects c set stage='ثانوي' from private.v223_backup_subjects b where b.id=c.id;
update public.curriculum_subjects set active=false, stage='ثانوي صناعي' where stage='ثانوي صناعي';
-- القواعد والإسنادات
update public.workload_rules set active=false where stage in ('ثانوي عام','ثانوي صناعي');
update public.workload_rules w set active=b.active from private.v223_backup_rules b where b.id=w.id;
update public.stage_coordinator_assignments set active=false where stage in ('ثانوي عام','ثانوي صناعي');
update public.stage_coordinator_assignments a set active=b.active from private.v223_backup_sca b where b.id=a.id;
update public.supervisor_stage_assignments set active=false where stage in ('ثانوي عام','ثانوي صناعي');
update public.supervisor_stage_assignments a set active=b.active from private.v223_backup_ssa b where b.supervisor_id=a.supervisor_id and b.stage=a.stage;
-- الدوال والعرض
do $$ declare r record; begin
 for r in select * from private.v223_backup_defs where kind='function' loop execute r.def; end loop;
 for r in select * from private.v223_backup_defs where kind='view' loop execute 'create or replace view public.teacher_workload_summary as '||r.def; end loop;
end $$;
-- (قيود المرحلة الموسّعة تبقى؛ تقبل «ثانوي» أيضًا.) ثم أعد نشر الواجهة v222/v221 وبوابة المنسق v177.
