-- v374: «إنجاز الجداول» لا يعرض المعلم في إجازة مجددة (teacher_long_leaves.renewal_status='renewed' للعام النشط، نفس تعريف teacher_workload_summary.on_renewed_leave)؛ يعود تلقائيًا عند تسجيل عودته.
-- بقرار المستخدم «أ» 2026-11-13. الاسترجاع: rollback_v374_timetable_progress_exclude_leave_2026-11-13.sql
create table if not exists private.v374_backup_functions(name text primary key, def text not null, saved_at timestamptz not null default now());
insert into private.v374_backup_functions(name, def)
  values ('public.timetable_progress(uuid)', pg_get_functiondef('public.timetable_progress(uuid)'::regprocedure))
  on conflict (name) do nothing;

CREATE OR REPLACE FUNCTION public.timetable_progress(p_term_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'private', 'public', 'pg_temp'
AS $function$
declare v_term uuid := coalesce(p_term_id,(select term_id from private.tp_active())); r public.app_role := private.current_app_role(); v jsonb;
begin
  if auth.uid() is null or r is null or r not in ('admin','first_supervisor','stage_coordinator','supervisor','school_manager','senior_teacher') then raise exception 'Unauthorized' using errcode='42501'; end if;
  -- v340: سطر لكل (معلم، مدرسة): المدرسة الأصلية + كل مدرسة له فيها فصول مسندة (المنتدب يظهر في المدرسة المنتدب إليها)؛ المطلوب والمدخل لحصص تلك المدرسة فقط
  with pairs as (
    select t.id teacher_id, t.home_school_id school_id from public.teacher_records t where t.active and t.home_school_id is not null
    union
    select a.teacher_id, c.school_id from public.teaching_assignments a join public.school_classes c on c.id=a.class_id join public.teacher_records t on t.id=a.teacher_id
     where a.term_id=v_term and t.active
  ), req as (
    select a.teacher_id, c.school_id, sum(a.weekly_periods)::int req from public.teaching_assignments a join public.school_classes c on c.id=a.class_id where a.term_id=v_term group by 1,2
  ), ent as (
    select teacher_id, school_id, count(*)::int cnt from public.teacher_timetable_slots where term_id=v_term group by 1,2
  )
  select coalesce(jsonb_agg(jsonb_build_object('school_id',s.id,'school_name',s.name,'stage',s.stage,'teacher_id',t.id,'teacher_name',t.full_name,'phone',t.phone,'work_type',t.work_type,'required',coalesce(q.req,0),'entered',coalesce(e.cnt,0),'is_home_school',t.home_school_id=s.id) order by s.stage,s.name,t.full_name),'[]'::jsonb)
    into v
    from pairs p join public.teacher_records t on t.id=p.teacher_id join public.schools s on s.id=p.school_id
    left join req q on q.teacher_id=p.teacher_id and q.school_id=p.school_id
    left join ent e on e.teacher_id=p.teacher_id and e.school_id=p.school_id
   where s.id = any(private.accessible_school_ids())
     -- v374: المعلم في إجازة مجددة لا يظهر حتى تُسجَّل عودته
     and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active
                      where l.teacher_id=t.id and l.renewal_status='renewed');
  return v;
end $function$;
