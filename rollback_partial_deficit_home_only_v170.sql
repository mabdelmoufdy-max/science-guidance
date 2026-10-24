-- استرجاع v170: إعادة ظهور عجز المنتدب جزئيًا في المدرسة المنتدب إليها كما كان (تعديل نصي عكسي لدالتي الكشف)
do $mig$
declare d text;
begin
  d:=pg_get_functiondef('private.school_teacher_roster(uuid,uuid)'::regprocedure);
  if (length(d)-length(replace(d,$q$      'deficit_periods',case
        when weekly_target is null then null
        when work_type='paid'::public.work_type then 0
        when delegation_to_school_id=p_school_id and delegation_type='partial'::public.delegation_type and home_school_id is distinct from p_school_id then 0  -- v170: عجز المنتدب جزئيًا في مدرسته الأصلية فقط
        else$q$,'')))/length($q$      'deficit_periods',case
        when weekly_target is null then null
        when work_type='paid'::public.work_type then 0
        when delegation_to_school_id=p_school_id and delegation_type='partial'::public.delegation_type and home_school_id is distinct from p_school_id then 0  -- v170: عجز المنتدب جزئيًا في مدرسته الأصلية فقط
        else$q$)<>1 then raise exception 'v170: target not found exactly once in private.school_teacher_roster(uuid,uuid)'; end if;
  d:=replace(d,$q$      'deficit_periods',case
        when weekly_target is null then null
        when work_type='paid'::public.work_type then 0
        when delegation_to_school_id=p_school_id and delegation_type='partial'::public.delegation_type and home_school_id is distinct from p_school_id then 0  -- v170: عجز المنتدب جزئيًا في مدرسته الأصلية فقط
        else$q$,$q$      'deficit_periods',case
        when weekly_target is null then null
        when work_type='paid'::public.work_type then 0
        else$q$);
  if (length(d)-length(replace(d,$q$        when weekly_target is null then 'غير محدد'
        when delegation_to_school_id=p_school_id and delegation_type='partial'::public.delegation_type and home_school_id is distinct from p_school_id and global_total_counted_periods<weekly_target then 'منتدب جزئيًا'  -- v170
        when global_total_counted_periods<weekly_target then 'عجز'$q$,'')))/length($q$        when weekly_target is null then 'غير محدد'
        when delegation_to_school_id=p_school_id and delegation_type='partial'::public.delegation_type and home_school_id is distinct from p_school_id and global_total_counted_periods<weekly_target then 'منتدب جزئيًا'  -- v170
        when global_total_counted_periods<weekly_target then 'عجز'$q$)<>1 then raise exception 'v170: target not found exactly once in private.school_teacher_roster(uuid,uuid)'; end if;
  d:=replace(d,$q$        when weekly_target is null then 'غير محدد'
        when delegation_to_school_id=p_school_id and delegation_type='partial'::public.delegation_type and home_school_id is distinct from p_school_id and global_total_counted_periods<weekly_target then 'منتدب جزئيًا'  -- v170
        when global_total_counted_periods<weekly_target then 'عجز'$q$,$q$        when weekly_target is null then 'غير محدد'
        when global_total_counted_periods<weekly_target then 'عجز'$q$);
  execute d;
  d:=pg_get_functiondef('private.school_teacher_rosters_all(uuid[],uuid)'::regprocedure);
  if (length(d)-length(replace(d,$q$when k.work_type='paid'::public.work_type then 0 when k.delegation_to_school_id=k._sid and k.delegation_type='partial'::public.delegation_type and k.home_school_id is distinct from k._sid then 0 else greatest(k.weekly_target-k.global_total_counted_periods,0) end,$q$,'')))/length($q$when k.work_type='paid'::public.work_type then 0 when k.delegation_to_school_id=k._sid and k.delegation_type='partial'::public.delegation_type and k.home_school_id is distinct from k._sid then 0 else greatest(k.weekly_target-k.global_total_counted_periods,0) end,$q$)<>1 then raise exception 'v170: target not found exactly once in private.school_teacher_rosters_all(uuid[],uuid)'; end if;
  d:=replace(d,$q$when k.work_type='paid'::public.work_type then 0 when k.delegation_to_school_id=k._sid and k.delegation_type='partial'::public.delegation_type and k.home_school_id is distinct from k._sid then 0 else greatest(k.weekly_target-k.global_total_counted_periods,0) end,$q$,$q$when k.work_type='paid'::public.work_type then 0 else greatest(k.weekly_target-k.global_total_counted_periods,0) end,$q$);
  if (length(d)-length(replace(d,$q$        when k.weekly_target is null then 'غير محدد'
        when k.delegation_to_school_id=k._sid and k.delegation_type='partial'::public.delegation_type and k.home_school_id is distinct from k._sid and k.global_total_counted_periods<k.weekly_target then 'منتدب جزئيًا'  -- v170
        when k.global_total_counted_periods<k.weekly_target then 'عجز'$q$,'')))/length($q$        when k.weekly_target is null then 'غير محدد'
        when k.delegation_to_school_id=k._sid and k.delegation_type='partial'::public.delegation_type and k.home_school_id is distinct from k._sid and k.global_total_counted_periods<k.weekly_target then 'منتدب جزئيًا'  -- v170
        when k.global_total_counted_periods<k.weekly_target then 'عجز'$q$)<>1 then raise exception 'v170: target not found exactly once in private.school_teacher_rosters_all(uuid[],uuid)'; end if;
  d:=replace(d,$q$        when k.weekly_target is null then 'غير محدد'
        when k.delegation_to_school_id=k._sid and k.delegation_type='partial'::public.delegation_type and k.home_school_id is distinct from k._sid and k.global_total_counted_periods<k.weekly_target then 'منتدب جزئيًا'  -- v170
        when k.global_total_counted_periods<k.weekly_target then 'عجز'$q$,$q$        when k.weekly_target is null then 'غير محدد'
        when k.global_total_counted_periods<k.weekly_target then 'عجز'$q$);
  execute d;
end
$mig$;
