-- v306: مؤشر إنجاز جداول المعلمين — دالة قراءة فقط (لا تغيّر أي بيانات).
-- للأدوار admin/first_supervisor/stage_coordinator/supervisor فقط وبنطاق private.accessible_school_ids().
create or replace function public.timetable_progress(p_term_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog','private','public','pg_temp' as $f$
declare v_term uuid := coalesce(p_term_id,(select term_id from private.tp_active())); r public.app_role := private.current_app_role(); v jsonb;
begin
  if auth.uid() is null or r is null or r not in ('admin','first_supervisor','stage_coordinator','supervisor') then raise exception 'Unauthorized' using errcode='42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('school_id',s.id,'school_name',s.name,'stage',s.stage,'teacher_id',t.id,'teacher_name',t.full_name,'phone',t.phone,'work_type',t.work_type,'required',coalesce(a.req,0),'entered',coalesce(sl.cnt,0)) order by s.stage,s.name,t.full_name),'[]'::jsonb)
    into v
    from public.teacher_records t
    join public.schools s on s.id=t.home_school_id
    left join (select teacher_id,sum(weekly_periods)::int req from public.teaching_assignments where term_id=v_term group by 1) a on a.teacher_id=t.id
    left join (select teacher_id,count(*)::int cnt from public.teacher_timetable_slots where term_id=v_term group by 1) sl on sl.teacher_id=t.id
   where t.active and s.id = any(private.accessible_school_ids());
  return v;
end $f$;
revoke all on function public.timetable_progress(uuid) from public;
grant execute on function public.timetable_progress(uuid) to authenticated;
