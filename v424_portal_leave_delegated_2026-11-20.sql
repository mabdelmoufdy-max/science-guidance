-- v424 مشرف المدرسة المنتدب إليها المعلم يسجّل له الإجازة القصيرة في أيامه بمدرسته فقط (حسب جدول المعلم) — 2026-11-20
-- بقول المستخدم: «مشرف المدرسة المنتدب إليها المعلم يضيف ليه في الأيام الموجودة عنده ويظهر ذاك من جدول المعلم».
-- (1) private.v423_ctx: يقبل المعلم المنتدب إلى مدرسة المشرف (انتداب ساري أو إسناد فيها) ويعيد delegated/school_id.
-- (2) private.v424_off_days: أيام العمل في الفترة التي ليس للمعلم فيها حصص بجدول تلك المدرسة.
-- (3) الإضافة والإلغاء للمنتدب: كل أيام الفترة من أيامه بالمدرسة وإلا رفض برسالة بالأيام.
-- (4) teacher_portal_leaves تعيد delegated وschool_days (أيام المعلم بالمدرسة من جدوله).
-- (5) طلب الإجازة الطويلة وسحبه: للمعلم ومشرف مدرسته الأصلية فقط (المنتدب إليها forbidden).
-- مشرف المدرسة الأصلية بلا تغيير. تعديل نصي مرة واحدة لكل موضع على النص المخزن.

create table if not exists private.v424_backup_functions (fn text primary key, def text not null, saved_at timestamptz default now());
insert into private.v424_backup_functions(fn, def)
select n.nspname || '.' || p.proname, pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where (n.nspname = 'private' and p.proname = 'v423_ctx')
    or (n.nspname = 'public' and p.proname in ('teacher_portal_leaves','teacher_portal_short_leave_add','teacher_portal_short_leave_cancel','teacher_portal_long_leave_request','teacher_portal_long_leave_withdraw'))
on conflict (fn) do nothing;

create or replace function private.v424_off_days(p_teacher uuid, p_school uuid, p_from date, p_to date)
returns text language sql stable security definer set search_path = public, private, pg_temp as $$
  select string_agg(distinct case extract(dow from d)::int when 6 then 'السبت' when 0 then 'الأحد' when 1 then 'الاثنين'
           when 2 then 'الثلاثاء' when 3 then 'الأربعاء' when 4 then 'الخميس' end, '، ')
    from generate_series(p_from, least(p_to, p_from + 90), interval '1 day') d
   where extract(dow from d) <> 5
     and not exists (select 1 from public.teacher_timetable_slots s
                      where s.teacher_id = p_teacher and s.school_id = p_school
                        and s.term_id = (select term_id from private.tp_active())
                        and s.weekday = extract(dow from d)::int)
$$;
revoke all on function private.v424_off_days(uuid, uuid, date, date) from public, anon, authenticated;

do $m$
declare
  fn text; d text; o text; r text; k int; i int; defs jsonb := '{}'::jsonb; oid_ regprocedure;
  edits text[][] := array[
    ['private.v423_ctx', $a$declare c jsonb; t record;$a$, $a$declare c jsonb; t record; v_deleg boolean;$a$],
    ['private.v423_ctx',
     $a$  if t.id is null or not t.active or t.home_school_id is distinct from (c ->> 'school_id')::uuid then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  return jsonb_build_object('ok', true, 'teacher_id', t.id, 'by', c ->> 'teacher_id', 'source', 'portal_sup', 'role', 'senior_teacher');$a$,
     $a$  if t.id is null or not t.active then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  v_deleg := t.home_school_id is distinct from (c ->> 'school_id')::uuid;
  if v_deleg and not exists (select 1 from public.delegations dl where dl.teacher_id = t.id and dl.active and dl.to_school_id = (c ->> 'school_id')::uuid)
     and not exists (select 1 from public.teaching_assignments ta join public.school_classes sc on sc.id = ta.class_id
                      where ta.teacher_id = t.id and ta.term_id = (select term_id from private.tp_active()) and sc.school_id = (c ->> 'school_id')::uuid) then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  return jsonb_build_object('ok', true, 'teacher_id', t.id, 'by', c ->> 'teacher_id', 'source', 'portal_sup', 'role', 'senior_teacher',
    'delegated', v_deleg, 'school_id', c ->> 'school_id');$a$],
    ['public.teacher_portal_leaves',
     $a$'short', v_short, 'long', v_long, 'requests', v_req);$a$,
     $a$'short', v_short, 'long', v_long, 'requests', v_req,
    'delegated', coalesce((x ->> 'delegated')::boolean, false),
    'school_days', case when coalesce((x ->> 'delegated')::boolean, false) then
      (select coalesce(jsonb_agg(distinct s.weekday), '[]'::jsonb) from public.teacher_timetable_slots s
        where s.teacher_id = tid and s.school_id = (x ->> 'school_id')::uuid and s.term_id = (select term_id from private.tp_active())) end);$a$],
    ['public.teacher_portal_short_leave_add',
     $a$  begin
    insert into public.teacher_short_leaves$a$,
     $a$  if coalesce((x ->> 'delegated')::boolean, false) and private.v424_off_days(tid, (x ->> 'school_id')::uuid, p_from, p_to) is not null then
    return jsonb_build_object('ok', false, 'reason', 'rejected', 'message',
      'المعلم ليس له حصص في مدرستك يوم: ' || private.v424_off_days(tid, (x ->> 'school_id')::uuid, p_from, p_to) || ' (حسب جدوله). سجّل أيامه في مدرستك فقط.');
  end if;
  begin
    insert into public.teacher_short_leaves$a$],
    ['public.teacher_portal_short_leave_cancel',
     $a$  if s.source not in ('portal_teacher','portal_sup') or s.date_from <= current_date then$a$,
     $a$  if coalesce((x ->> 'delegated')::boolean, false) and private.v424_off_days(tid, (x ->> 'school_id')::uuid, s.date_from, s.date_to) is not null then
    return jsonb_build_object('ok', false, 'reason', 'rejected', 'message', 'هذه الإجازة تشمل أيامًا خارج مدرستك؛ يلغيها مشرف مدرسته الأصلية أو المعلم.');
  end if;
  if s.source not in ('portal_teacher','portal_sup') or s.date_from <= current_date then$a$],
    ['public.teacher_portal_long_leave_request',
     $a$  if p_type not in ('إجازة وضع'$a$,
     $a$  if coalesce((x ->> 'delegated')::boolean, false) then
    return jsonb_build_object('ok', false, 'reason', 'rejected', 'message', 'طلب الإجازة الطويلة يقدّمه المعلم أو مشرف مدرسته الأصلية.');
  end if;
  if p_type not in ('إجازة وضع'$a$],
    ['public.teacher_portal_long_leave_withdraw',
     $a$  select * into r from public.teacher_long_leave_requests$a$,
     $a$  if coalesce((x ->> 'delegated')::boolean, false) then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select * into r from public.teacher_long_leave_requests$a$]
  ];
begin
  for i in 1 .. array_length(edits, 1) loop
    fn := edits[i][1]; o := edits[i][2]; r := edits[i][3];
    if defs ? fn then d := defs ->> fn;
    else
      select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname || '.' || p.proname = fn;
    end if;
    k := (length(d) - length(replace(d, o, ''))) / length(o);
    if k <> 1 then raise exception 'v424: % edit % matched % times', fn, i, k; end if;
    defs := jsonb_set(defs, array[fn], to_jsonb(replace(d, o, r)), true);
  end loop;
  for fn in select jsonb_object_keys(defs) loop execute defs ->> fn; end loop;
end
$m$;
