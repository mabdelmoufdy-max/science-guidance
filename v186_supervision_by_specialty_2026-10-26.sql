-- v186 (2026-10-26، بطلب المستخدم): مشرف مادة لكل تخصص (فيزياء/كيمياء/أحياء) في 6 مدارس ثانوية عامة:
-- العسكرية، الشهداء ث بنات، السكر ث بنات، الحراجية ث، جراجوس ث، حجازة ث.
-- بقية المدارس (شنهور/خالد/خزام ث، والصناعية الثلاث، وكل المراحل الأخرى) بمشرف واحد للمدرسة كما هي.
-- + تسجيل هالة سيد أحمد سيد مدرسة أصلية في العسكرية (كان ينقصها سجل المدرسة الأصلية فتغيب عن الكشف).
-- الاسترجاع: rollback_v186_supervision_by_specialty_2026-10-26.sql
-- التنفيذ بمعاملة واحدة وبتحقق ذاتي: أي اختلاف ينهي المعاملة ولا يُحفظ شيء.

begin;

-- 0) نسخ احتياطي للاسترجاع
create table private.v186_backup_defs (name text primary key, def text not null);
insert into private.v186_backup_defs (name, def)
select p.oid::regprocedure::text, pg_get_functiondef(p.oid)
from pg_proc p
where p.oid in (
  'private.sync_school_senior_teacher(uuid)'::regprocedure,
  'public.set_school_supervisor(uuid,uuid)'::regprocedure,
  'private.school_teacher_roster(uuid,uuid)'::regprocedure,
  'private.school_teacher_rosters_all(uuid[],uuid)'::regprocedure,
  'public.get_teacher_leave_replacement_candidates(uuid,uuid)'::regprocedure);
create table private.v186_backup_flags as select id, is_senior_teacher from public.teacher_records;
create table private.v186_backup_choice as select * from public.school_supervisor_choice;
create table private.v186_backup_rows (what text primary key, row_id uuid);

-- بصمة أنصبة المعلمين خارج المدارس الست قبل التعديل (يجب ألا تتغير)
create temp table v186_before on commit drop as
select w.teacher_id, md5(to_jsonb(w)::text) as h
from public.teacher_workload_summary w
where not exists (
  select 1 from public.schools s
  where s.id = w.home_school_id
    and s.name in ('قوص ث العسكرية بنين','الشهداء ث بنات','السكر ث بنات','الحراجية ث المشتركة','جراجوس ث المشتركة','حجازة ث المشتركة'));

-- 1) الأعمدة والقيود
alter table public.schools add column supervise_by_specialty boolean not null default false;
alter table public.teacher_records add column sup_group text not null default '';
alter table public.school_supervisor_choice add column grp text not null default '';
alter table public.school_supervisor_choice drop constraint school_supervisor_choice_pkey;
alter table public.school_supervisor_choice add constraint school_supervisor_choice_pkey primary key (school_id, grp);
drop index public.one_active_senior_teacher_per_school;

-- 2) دوال مساعدة
create or replace function private.sup_group_key(p_specialty text) returns text
language sql immutable parallel safe
as $$ select case
    when p_specialty is null then null
    when p_specialty like '%فيزياء%' and p_specialty like '%كيمياء%' then null
    when p_specialty like '%فيزياء%' then 'الفيزياء'
    when p_specialty like '%كيمياء%' then 'الكيمياء'
    when p_specialty like '%حياء%' then 'الأحياء'
    else null end $$;

create or replace function private.sup_group_of(p_school_id uuid, p_specialty text) returns text
language sql stable security definer set search_path = pg_catalog, public, pg_temp
as $$ select case
    when coalesce((select s.supervise_by_specialty from public.schools s where s.id = p_school_id), false)
      then coalesce(private.sup_group_key(p_specialty), '')
    else '' end $$;

-- 3) تفعيل الإشراف بالتخصص على المدارس الست وتعبئة مجموعة كل معلم (دون إثارة المشغّلات)
do $d1$
declare v_n int;
begin
  set local session_replication_role = replica;
  update public.schools set supervise_by_specialty = true
   where name in ('قوص ث العسكرية بنين','الشهداء ث بنات','السكر ث بنات','الحراجية ث المشتركة','جراجوس ث المشتركة','حجازة ث المشتركة');
  get diagnostics v_n = row_count;
  if v_n <> 6 then raise exception 'v186: المتوقع 6 مدارس وجد %', v_n; end if;
  update public.teacher_records tr
     set sup_group = private.sup_group_of(tr.home_school_id, tr.specialty)
   where tr.home_school_id in (select id from public.schools where supervise_by_specialty);
  set local session_replication_role = origin;
end $d1$;

create unique index one_active_senior_teacher_per_school
  on public.teacher_records (home_school_id, sup_group)
  where (is_senior_teacher and active and home_school_id is not null);

-- 4) مشغلات الحفاظ على مجموعة التخصص
create or replace function private.teacher_records_sup_group_trigger() returns trigger
language plpgsql security definer set search_path = pg_catalog, public, pg_temp
as $$
begin
  new.sup_group := private.sup_group_of(new.home_school_id, new.specialty);
  return new;
end $$;
create trigger trg_teacher_records_sup_group
  before insert or update of specialty, home_school_id on public.teacher_records
  for each row execute function private.teacher_records_sup_group_trigger();

-- 5) مزامنة المشرفين: مشرف لكل (مدرسة، مجموعة)؛ المجموعة '' لغير المدارس المفعّلة = مشرف واحد كما كان
create or replace function private.sync_school_senior_teacher(p_school_id uuid)
returns void
language plpgsql security definer
set search_path to 'pg_catalog', 'private', 'public', 'pg_temp'
as $fn$
declare
  v_by_spec boolean;
  v_winners uuid[];
begin
  if p_school_id is null then
    return;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text, 7242026));

  select coalesce(s.supervise_by_specialty, false) into v_by_spec from public.schools s where s.id = p_school_id;

  with active_delegations as (
    select d.*
    from public.delegations d
    where d.active
      and d.start_date <= current_date
      and (d.end_date is null or d.end_date >= current_date)
  ), scope_members as (
    select tr.id as teacher_id
    from public.teacher_records tr
    where tr.home_school_id = p_school_id
      and tr.active
      and tr.work_type = 'permanent'::public.work_type
      and not exists (
        select 1
        from active_delegations d
        where d.teacher_id = tr.id
          and d.from_school_id = p_school_id
          and d.delegation_type = 'full'::public.delegation_type
      )
    union
    select tr.id
    from active_delegations d
    join public.teacher_records tr on tr.id = d.teacher_id
    where d.to_school_id = p_school_id
      and d.delegation_type = 'full'::public.delegation_type
      and tr.active
      and tr.work_type = 'permanent'::public.work_type
  ), cand as (
    select tr.id,
           case when v_by_spec then private.sup_group_key(tr.specialty) else '' end as g,
           tr.job_title, tr.grade_acquired_date, tr.work_start_date, tr.appointment_date,
           tr.is_senior_teacher, tr.created_at
    from scope_members sm
    join public.teacher_records tr on tr.id = sm.teacher_id
    where not exists (select 1 from public.supervision_declined sd where sd.teacher_id = tr.id and sd.school_id = p_school_id)
      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id = tr.id and c1.school_id <> p_school_id)
  ), best as (
    select distinct on (c.g) c.id, c.g
    from cand c
    where c.g is not null
    order by c.g,
             public.teacher_job_grade_rank(c.job_title) desc,
             c.grade_acquired_date asc nulls last,
             c.work_start_date asc nulls last,
             c.appointment_date asc nulls last,
             c.is_senior_teacher desc,
             c.created_at asc,
             c.id
  )
  select coalesce(array_agg(x.id), '{}'::uuid[])
  into v_winners
  from (
    -- اختيار الموجه يتقدم على الأقدمية (teacher_id فارغ = شاغر لهذه المجموعة)
    select c.teacher_id as id from public.school_supervisor_choice c
     where c.school_id = p_school_id and c.teacher_id is not null
    union
    select b.id from best b
     where not exists (select 1 from public.school_supervisor_choice c where c.school_id = p_school_id and c.grp = b.g)
  ) x;

  update public.teacher_records tr
  set is_senior_teacher = false,
      updated_at = now()
  where tr.is_senior_teacher
    and not (tr.id = any(v_winners))
    and (
      (
        tr.home_school_id = p_school_id
        and not exists (
          select 1
          from public.delegations d
          where d.teacher_id = tr.id
            and d.from_school_id = p_school_id
            and d.delegation_type = 'full'::public.delegation_type
            and d.active
            and d.start_date <= current_date
            and (d.end_date is null or d.end_date >= current_date)
        )
      )
      or exists (
        select 1
        from public.delegations d
        where d.teacher_id = tr.id
          and d.to_school_id = p_school_id
          and d.delegation_type = 'full'::public.delegation_type
          and d.active
          and d.start_date <= current_date
          and (d.end_date is null or d.end_date >= current_date)
      )
    );

  if cardinality(v_winners) > 0 then
    update public.teacher_records tr
    set is_senior_teacher = true,
        updated_at = now()
    where tr.id = any(v_winners)
      and tr.is_senior_teacher is distinct from true
      and (tr.home_school_id = p_school_id or exists (select 1 from public.delegations d where d.teacher_id = tr.id and d.to_school_id = p_school_id and d.delegation_type = 'full'::public.delegation_type and d.active and d.start_date <= current_date and (d.end_date is null or d.end_date >= current_date)));
  end if;
end
$fn$;

create or replace function private.schools_sup_group_trigger() returns trigger
language plpgsql security definer set search_path = pg_catalog, private, public, pg_temp
as $$
begin
  if not new.supervise_by_specialty and exists (select 1 from public.school_supervisor_choice c where c.school_id = new.id and c.grp <> '') then
    raise exception 'لا يمكن إلغاء الإشراف بالتخصص قبل إزالة اختيارات المشرفين لكل تخصص في هذه المدرسة';
  end if;
  if not new.supervise_by_specialty then
    update public.teacher_records set is_senior_teacher = false where home_school_id = new.id and is_senior_teacher;
  end if;
  update public.teacher_records tr
     set sup_group = private.sup_group_of(new.id, tr.specialty)
   where tr.home_school_id = new.id
     and tr.sup_group is distinct from private.sup_group_of(new.id, tr.specialty);
  perform private.sync_school_senior_teacher(new.id);
  return new;
end $$;
create trigger trg_schools_sup_group
  after update of supervise_by_specialty on public.schools
  for each row when (old.supervise_by_specialty is distinct from new.supervise_by_specialty)
  execute function private.schools_sup_group_trigger();

-- 6) تعيين مشرف المادة من الواجهة: المجموعة تُستنتج من تخصص المعلم؛ ولإلغاء الإشراف في مدرسة مفعّلة يلزم p_group
drop function public.set_school_supervisor(uuid, uuid);
create or replace function public.set_school_supervisor(p_school_id uuid, p_teacher_id uuid, p_group text default null)
returns jsonb
language plpgsql security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare
  v_role public.app_role := private.current_app_role();
  v_prev uuid; v_other_school uuid; v_other_grp text; v_home uuid; v_prev_home uuid; v_name text; v_prev_name text;
  v_spec text; v_by_spec boolean; v_grp text;
begin
  if auth.uid() is null then raise exception 'Unauthorized' using errcode='42501'; end if;
  if v_role is null or v_role::text not in ('admin','stage_coordinator','supervisor') then
    raise exception 'تعديل مشرف المادة متاح للموجه ومنسق المرحلة ومدير النظام فقط' using errcode='42501';
  end if;
  if p_school_id is null or not private.can_access_school(p_school_id) then
    raise exception 'المدرسة خارج نطاق صلاحيتك' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('set_school_supervisor', 7242026));

  select coalesce(s.supervise_by_specialty, false) into v_by_spec from public.schools s where s.id = p_school_id;

  if p_teacher_id is not null then
    select tr.home_school_id, tr.full_name, tr.specialty into v_home, v_name, v_spec from public.teacher_records tr
     where tr.id=p_teacher_id and tr.active and tr.work_type='permanent'::public.work_type;
    if not found then raise exception 'مشرف المادة يجب أن يكون معلمًا ثابتًا نشطًا'; end if;
    if v_home is distinct from p_school_id and not exists (
      select 1 from public.delegations d where d.teacher_id=p_teacher_id and d.to_school_id=p_school_id and d.active
        and d.start_date<=current_date and (d.end_date is null or d.end_date>=current_date)) then
      raise exception 'المعلم ليس من معلمي هذه المدرسة (لا هي مدرسته الأصلية ولا منتدب إليها)';
    end if;
    if exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active
               where l.teacher_id=p_teacher_id and l.renewal_status='renewed') then
      raise exception 'المعلم في إجازة مجددة ولا يتولى الإشراف';
    end if;
    v_grp := case when v_by_spec then private.sup_group_key(v_spec) else '' end;
    if v_grp is null then
      raise exception 'حدّد تخصص المعلم (فيزياء أو كيمياء أو أحياء) قبل تعيينه مشرفًا لمادته في هذه المدرسة';
    end if;
    -- المعلم يشرف على مجموعة واحدة فقط: يُرفع اختياره من أي مدرسة/مجموعة أخرى (تصبح شاغرة)
    select c.school_id, c.grp into v_other_school, v_other_grp from public.school_supervisor_choice c
     where c.teacher_id=p_teacher_id and not (c.school_id=p_school_id and c.grp=v_grp);
    if v_other_school is null and v_home is distinct from p_school_id
       and exists (select 1 from public.teacher_records tr where tr.id=p_teacher_id and tr.is_senior_teacher)
       and not exists (select 1 from public.school_supervisor_choice c where c.school_id=v_home and c.grp=private.sup_group_of(v_home, v_spec)) then
      v_other_school := v_home;  -- كان مشرفًا في مدرسته الأصلية بالأقدمية
      v_other_grp := private.sup_group_of(v_home, v_spec);
    end if;
    if v_other_school is not null then
      insert into public.school_supervisor_choice(school_id,grp,teacher_id,note,chosen_at,chosen_by)
      values (v_other_school,v_other_grp,null,'شاغر: نُقل مشرفها إلى مدرسة أخرى',now(),auth.uid())
      on conflict (school_id,grp) do update set teacher_id=null, note=excluded.note, chosen_at=excluded.chosen_at, chosen_by=excluded.chosen_by;
    end if;
  else
    if v_by_spec then
      v_grp := private.sup_group_key(p_group);
      if v_grp is null then
        raise exception 'حدّد التخصص (الفيزياء أو الكيمياء أو الأحياء) لإلغاء مشرف المادة في هذه المدرسة؛ حدّث الصفحة (Ctrl+F5)';
      end if;
    else
      v_grp := '';
    end if;
  end if;

  select c.teacher_id into v_prev from public.school_supervisor_choice c where c.school_id=p_school_id and c.grp=v_grp;
  if v_prev is null then
    select tr.id into v_prev from public.teacher_records tr
     where tr.home_school_id=p_school_id and tr.active and tr.is_senior_teacher and tr.sup_group=v_grp limit 1;
  end if;
  select tr.home_school_id, tr.full_name into v_prev_home, v_prev_name from public.teacher_records tr where tr.id=v_prev;

  insert into public.school_supervisor_choice(school_id,grp,teacher_id,note,chosen_at,chosen_by)
  values (p_school_id,v_grp,p_teacher_id,case when p_teacher_id is null then 'إلغاء الإشراف من تعديل بيانات المعلم' else 'من تعديل بيانات المعلم' end,now(),auth.uid())
  on conflict (school_id,grp) do update set teacher_id=excluded.teacher_id, note=excluded.note, chosen_at=excluded.chosen_at, chosen_by=excluded.chosen_by;

  perform private.sync_school_senior_teacher(s) from (
    select p_school_id s union select v_other_school union select v_home union select v_prev_home) x where s is not null;

  return jsonb_build_object('school_id',p_school_id,'group',v_grp,'teacher_id',p_teacher_id,'teacher_name',v_name,
    'previous_teacher_id',v_prev,'previous_teacher_name',v_prev_name,'cleared_school_id',v_other_school);
end
$fn$;
revoke all on function public.set_school_supervisor(uuid, uuid, text) from public, anon;
grant execute on function public.set_school_supervisor(uuid, uuid, text) to authenticated, service_role;

-- 7) الكشفان (مدرسة واحدة / عدة مدارس) + مرشحو بديل الإجازة: تعديل نصي دقيق على التعريف القائم (كل استبدال يجب أن يطابق مرة واحدة)
create or replace function pg_temp.v186_rep(p_def text, p_old text, p_new text) returns text
language plpgsql as $$
declare n int;
begin
  n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  if n <> 1 then raise exception 'v186: الاستبدال طابق % مرة (المتوقع 1): %', n, left(p_old, 90); end if;
  return replace(p_def, p_old, p_new);
end $$;

do $d2$
declare v text;
begin
  -- 7أ) كشف مدرسة واحدة
  v := pg_get_functiondef('private.school_teacher_roster(uuid,uuid)'::regprocedure);
  v := pg_temp.v186_rep(v, $o$    select c.teacher_id from public.school_supervisor_choice c where c.school_id=p_school_id  -- v183$o$,
                           $n$    select c.teacher_id, c.grp from public.school_supervisor_choice c where c.school_id=p_school_id  -- v183$n$);
  v := pg_temp.v186_rep(v, $o$    (select tr.id as teacher_id$o$,
                           $n$    (select distinct on (private.sup_group_of(p_school_id, tr.specialty)) tr.id as teacher_id$n$);
  v := pg_temp.v186_rep(v, $o$    where not exists (select 1 from supervisor_choice)$o$,
                           $n$    where not exists (select 1 from supervisor_choice sc9 where sc9.grp = private.sup_group_of(p_school_id, tr.specialty))
      and (private.sup_group_of(p_school_id, tr.specialty) <> '' or not coalesce((select s9.supervise_by_specialty from public.schools s9 where s9.id=p_school_id), false))$n$);
  v := pg_temp.v186_rep(v, $o$    order by public.teacher_job_grade_rank(tr.job_title) desc,$o$,
                           $n$    order by private.sup_group_of(p_school_id, tr.specialty), public.teacher_job_grade_rank(tr.job_title) desc,$n$);
  v := pg_temp.v186_rep(v, E'    limit 1)\n  ), scope_teaching as (', E'    )\n  ), scope_teaching as (');
  v := pg_temp.v186_rep(v, $o$      (ss.teacher_id=w.teacher_id) as scope_is_senior_teacher,$o$,
                           $n$      (case when ssl.has_ss then ssl.is_ss end) as scope_is_senior_teacher,$n$);
  v := pg_temp.v186_rep(v, $o$      case when ss.teacher_id=w.teacher_id and w.work_type='permanent'::public.work_type then 2 else 0 end::integer as scope_supervision_periods,$o$,
                           $n$      case when coalesce(ssl.is_ss,false) and w.work_type='permanent'::public.work_type then 2 else 0 end::integer as scope_supervision_periods,$n$);
  v := pg_temp.v186_rep(v, $o$        when ss.teacher_id=w.teacher_id then 2$o$,
                           $n$        when coalesce(ssl.is_ss,false) then 2$n$);
  v := pg_temp.v186_rep(v, $o$    left join scope_supervisor ss on true$o$,
                           $n$    left join lateral (select exists(select 1 from scope_supervisor) as has_ss, exists(select 1 from scope_supervisor ssx where ssx.teacher_id=w.teacher_id) as is_ss) ssl on true$n$);
  execute v;

  -- 7ب) كشف عدة مدارس
  v := pg_get_functiondef('private.school_teacher_rosters_all(uuid[],uuid)'::regprocedure);
  v := pg_temp.v186_rep(v, $o$    select p.sid, tr.id as tid,$o$,
                           $n$    select p.sid, tr.id as tid, private.sup_group_of(p.sid, tr.specialty) as grp,$n$);
  v := pg_temp.v186_rep(v, $o$      row_number() over (partition by p.sid order by public.teacher_job_grade_rank(tr.job_title) desc,$o$,
                           $n$      row_number() over (partition by p.sid, private.sup_group_of(p.sid, tr.specialty) order by public.teacher_job_grade_rank(tr.job_title) desc,$n$);
  v := pg_temp.v186_rep(v, $o$      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p.sid)  -- v183$o$,
                           $n$      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p.sid)  -- v183
      and (private.sup_group_of(p.sid, tr.specialty) <> '' or not coalesce((select s9.supervise_by_specialty from public.schools s9 where s9.id=p.sid), false))$n$);
  v := pg_temp.v186_rep(v, $o$    select r.sid, r.tid from ranked r where r.rn=1 and not exists (select 1 from public.school_supervisor_choice c where c.school_id=r.sid)$o$,
                           $n$    select r.sid, r.tid from ranked r where r.rn=1 and not exists (select 1 from public.school_supervisor_choice c where c.school_id=r.sid and c.grp=r.grp)$n$);
  v := pg_temp.v186_rep(v, $o$      (ss.tid=w.teacher_id) as scope_is_senior_teacher,$o$,
                           $n$      (case when ssl.has_ss then ssl.is_ss end) as scope_is_senior_teacher,$n$);
  v := pg_temp.v186_rep(v, $o$      case when ss.tid=w.teacher_id and w.work_type='permanent'::public.work_type then 2 else 0 end::integer as scope_supervision_periods,$o$,
                           $n$      case when coalesce(ssl.is_ss,false) and w.work_type='permanent'::public.work_type then 2 else 0 end::integer as scope_supervision_periods,$n$);
  v := pg_temp.v186_rep(v, $o$        when ss.tid=w.teacher_id then 2$o$,
                           $n$        when coalesce(ssl.is_ss,false) then 2$n$);
  v := pg_temp.v186_rep(v, $o$    left join ss on ss.sid=p.sid$o$,
                           $n$    left join lateral (select exists(select 1 from ss ssy where ssy.sid=p.sid) as has_ss, exists(select 1 from ss ssx where ssx.sid=p.sid and ssx.tid=w.teacher_id) as is_ss) ssl on true$n$);
  execute v;

  -- 7ج) مرشحو بديل مشرف المادة عند تجديد إجازته: من التخصص نفسه
  v := pg_get_functiondef('public.get_teacher_leave_replacement_candidates(uuid,uuid)'::regprocedure);
  v := pg_temp.v186_rep(v, E'  v_school_id uuid;\n  v_role public.app_role;', E'  v_school_id uuid;\n  v_grp text;\n  v_role public.app_role;');
  v := pg_temp.v186_rep(v, $o$  select tr.home_school_id into v_school_id$o$,
                           $n$  select tr.home_school_id, tr.sup_group into v_school_id, v_grp$n$);
  v := pg_temp.v186_rep(v, E'    where tr.home_school_id = v_school_id\n      and tr.id <> p_teacher_id',
                           E'    where tr.home_school_id = v_school_id\n      and tr.sup_group = v_grp\n      and tr.id <> p_teacher_id');
  execute v;
end $d2$;

-- 8) البيانات: اختيارات الموجه (18 مشرفًا) + سجل هالة الأصلي + المزامنة
do $d3$
declare v_n int; v_tsa uuid; v_owner uuid := '57e5112f-629b-479a-b7bd-8db465edcca3';
begin
  insert into public.school_supervisor_choice (school_id, grp, teacher_id, note, chosen_at, chosen_by)
  select s.id, v.grp, t.id, 'اختيار الموجه 2026-10-26 — مشرف لكل تخصص', now(), v_owner
  from (values
    ('قوص ث العسكرية بنين','الفيزياء','هالة سيد أحمد سيد'),
    ('قوص ث العسكرية بنين','الكيمياء','خليل محمد حليل أحمد'),
    ('قوص ث العسكرية بنين','الأحياء','محمد أبو الحمد محمد مسعود'),
    ('الشهداء ث بنات','الفيزياء','منال عبد الله يونس عبداللاه'),
    ('الشهداء ث بنات','الكيمياء','منال محمد أحمد عبد الرحيم'),
    ('الشهداء ث بنات','الأحياء','أشرف عبد الغني محمود'),
    ('السكر ث بنات','الفيزياء','صفاء عبد الفتاح محمد'),
    ('السكر ث بنات','الكيمياء','زينب أبو الحسن عبد الراضي'),
    ('السكر ث بنات','الأحياء','حنان محمد مصطفى محمد'),
    ('الحراجية ث المشتركة','الفيزياء','هدى عبد الله بكري عبدالله'),
    ('الحراجية ث المشتركة','الكيمياء','أحمد يونس محمود علي'),
    ('الحراجية ث المشتركة','الأحياء','هدى إبراهيم جاد الرب سليمان'),
    ('جراجوس ث المشتركة','الفيزياء','محمود حزين علي محمد'),
    ('جراجوس ث المشتركة','الكيمياء','ميلاد رسمي عطيتو اندراوس'),
    ('جراجوس ث المشتركة','الأحياء','أبو القاسم محمد حسنين'),
    ('حجازة ث المشتركة','الفيزياء','عربي مصطفى عباس حداد'),
    ('حجازة ث المشتركة','الكيمياء','محمود أبو الوفا عبد العاطي'),
    ('حجازة ث المشتركة','الأحياء','أسامة أحمد محمد محمد')
  ) v(school, grp, tname)
  join public.schools s on s.name = v.school
  join public.teacher_records t on t.home_school_id = s.id and t.full_name = v.tname and t.active
       and t.work_type = 'permanent'::public.work_type and private.sup_group_key(t.specialty) = v.grp;
  get diagnostics v_n = row_count;
  if v_n <> 18 then raise exception 'v186: المتوقع 18 اختيارًا وأُدخل %', v_n; end if;

  -- هالة: سجل المدرسة الأصلية في العسكرية (كان لها سجل الصناعية فقط)
  insert into public.teacher_school_assignments (teacher_id, school_id, is_home_school, active, term_id, academic_year_id)
  select 'd5ef5a0d-ba13-47a1-ba62-b090a3c5bf59'::uuid, '95cd86a1-3cf2-4238-babc-d15eb3c3a74c'::uuid, true, true, a.term_id, a.academic_year_id
  from public.teacher_school_assignments a where a.id = '45602271-a00e-4ed6-bd1c-cabf83451d00'
  returning id into v_tsa;
  insert into private.v186_backup_rows (what, row_id) values ('hala_home_tsa', v_tsa);

  perform private.sync_school_senior_teacher(s.id) from public.schools s where s.supervise_by_specialty;
end $d3$;

-- 9) التحقق الذاتي: أي فشل يُلغي المعاملة كاملة
do $chk$
declare v_bad int; v_cnt int; v_term uuid; v_ids uuid[]; v_all jsonb; v_sid uuid;
begin
  select count(*) into v_bad from v186_before b
    join public.teacher_workload_summary w on w.teacher_id = b.teacher_id
   where md5(to_jsonb(w)::text) <> b.h;
  if v_bad > 0 then raise exception 'v186: تغيّر % معلمًا خارج المدارس الست', v_bad; end if;

  select count(*) into v_cnt from public.teacher_records tr join public.schools s on s.id = tr.home_school_id
   where s.supervise_by_specialty and tr.is_senior_teacher and tr.active;
  if v_cnt <> 18 then raise exception 'v186: المشرفون المعلّمون في المدارس الست % والمتوقع 18', v_cnt; end if;

  perform set_config('request.jwt.claims', '{"sub":"57e5112f-629b-479a-b7bd-8db465edcca3","role":"authenticated"}', true);
  perform set_config('request.headers', '{"x-app-role":"admin"}', true);
  select term_id into v_term from private.tp_active();
  select array_agg(id) into v_ids from (
    select id from public.schools where supervise_by_specialty
    union
    (select id from public.schools order by id limit 40)) x;
  select jsonb_object_agg(out_school_id::text, out_rows) into v_all from private.school_teacher_rosters_all(v_ids, v_term);
  for v_sid in select unnest(v_ids) loop
    if private.school_teacher_roster(v_sid, v_term) is distinct from coalesce(v_all -> (v_sid::text), '[]'::jsonb) then
      raise exception 'v186: اختلاف كشف المدرسة % بين الدالتين', v_sid;
    end if;
  end loop;

  select count(*) into v_cnt from jsonb_array_elements(private.school_teacher_roster('95cd86a1-3cf2-4238-babc-d15eb3c3a74c', v_term)) r
   where (r ->> 'scope_is_senior_teacher')::boolean;
  if v_cnt <> 3 then raise exception 'v186: مشرفو العسكرية في الكشف % والمتوقع 3', v_cnt; end if;
end $chk$;

commit;
