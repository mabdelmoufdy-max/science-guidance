-- v423 الإجازات في بوابة المعلمين — المراحل 5–7 من docs/PLAN_portal_leaves.md (2026-11-20)
-- المعلم لنفسه والمشرف (مشرف/مسؤول بيانات/الأساسي الوحيد/المنتدب — مدرسته فقط، المعلمون الأصليون فيها):
--   القصيرة (عارضة/اعتيادي) تُسجَّل مباشرة بلا اعتماد؛ المشغّل v421 يفرض كل القواعد.
--   الطويلة = طلب بانتظار اعتماد الموجه (لا يغيّر شيئًا حتى يُعتمد في البرنامج — المراحل 8–10 في محادثة الإجازات).
-- إضافية فقط: لا تعديل لأي دالة أو جدول قائم عدا عمود مفتاح جديد في teacher_portal_settings.
-- قرارات افتراضية (من الخطة، قابلة للتغيير): الإلغاء للمسجّل من البوابة قبل بدايته فقط؛ المشرف لمعلمي مدرسته الأصليين فقط؛
-- أنواع الطويلة = قائمة البرنامج الرئيسي؛ بلا مرفقات.

alter table public.teacher_portal_settings add column if not exists leaves_open boolean not null default true;

create table if not exists public.teacher_long_leave_requests (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null,
  leave_type text not null check (leave_type in ('إجازة وضع','رعاية طفل','مرافقة زوج أو زوجة','إجازة مرضية طويلة','إصابة عمل','رعاية أحد أفراد الأسرة','إجازة بدون مرتب','إجازة طويلة أخرى')),
  date_from date not null,
  date_to date,
  notes text,
  source text not null check (source in ('portal_teacher','portal_sup')),
  requested_by uuid,
  status text not null default 'pending' check (status in ('pending','approved','rejected','withdrawn')),
  reviewed_by uuid, reviewed_at timestamptz, review_note text, long_leave_id uuid,
  created_at timestamptz not null default now(),
  constraint teacher_long_leave_requests_dates check (date_to is null or date_to >= date_from)
);
create index if not exists teacher_long_leave_requests_teacher_idx on public.teacher_long_leave_requests(teacher_id, status);
alter table public.teacher_long_leave_requests enable row level security;
revoke all on public.teacher_long_leave_requests from anon, authenticated;

-- من المتحقق ومن المعلم المقصود
create or replace function private.v423_ctx(p_civil text, p_phone text, p_teacher_id uuid)
returns jsonb language plpgsql security definer set search_path = public, private, pg_temp as $$
declare c jsonb; t record;
begin
  if p_teacher_id is null then
    c := private.tp_check(p_civil, p_phone);
    if c ->> 'status' <> 'ok' then return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['teacher_id','status','limited']); end if;
    if coalesce((c ->> 'limited')::boolean, false) then return jsonb_build_object('ok', false, 'reason', 'no_phone'); end if;
    return jsonb_build_object('ok', true, 'teacher_id', c ->> 'teacher_id', 'by', c ->> 'teacher_id', 'source', 'portal_teacher', 'role', 'teacher');
  end if;
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']); end if;
  select id, active, home_school_id into t from public.teacher_records where id = p_teacher_id;
  if t.id is null or not t.active or t.home_school_id is distinct from (c ->> 'school_id')::uuid then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  return jsonb_build_object('ok', true, 'teacher_id', t.id, 'by', c ->> 'teacher_id', 'source', 'portal_sup', 'role', 'senior_teacher');
end $$;
revoke all on function private.v423_ctx(text, text, uuid) from public, anon, authenticated;

-- الرصيد والقائمة والطلبات
create or replace function public.teacher_portal_leaves(p_civil text, p_phone text, p_teacher_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_temp as $$
declare x jsonb; tid uuid; t record; c_start date; a_start date; c_used int; a_used int; a_lim int; v_open boolean;
        v_short jsonb; v_long jsonb; v_req jsonb;
begin
  x := private.v423_ctx(p_civil, p_phone, p_teacher_id);
  if not (x ->> 'ok')::boolean then return x; end if;
  tid := (x ->> 'teacher_id')::uuid;
  select id, full_name, work_type, job_title into t from public.teacher_records where id = tid;
  select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;
  c_start := private.v421_year_start('عارضة', current_date);
  a_start := private.v421_year_start('اعتيادي', current_date);
  select coalesce(sum(days),0) into c_used from public.teacher_short_leaves where teacher_id = tid and leave_type = 'عارضة' and year_start = c_start and cancelled_at is null;
  select coalesce(sum(days),0) into a_used from public.teacher_short_leaves where teacher_id = tid and leave_type = 'اعتيادي' and year_start = a_start and cancelled_at is null;
  a_lim := private.v421_annual_limit(t.job_title);
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'type', s.leave_type, 'from', s.date_from, 'to', s.date_to, 'days', s.days,
           'notes', s.notes, 'source', s.source, 'cancelled', s.cancelled_at is not null,
           'can_cancel', s.cancelled_at is null and s.source in ('portal_teacher','portal_sup') and s.date_from > current_date)
         order by s.date_from desc), '[]'::jsonb)
    into v_short from public.teacher_short_leaves s
   where s.teacher_id = tid and s.date_from >= least(c_start, a_start) - interval '1 year';
  select jsonb_build_object('type', l.leave_type, 'from', l.effective_from, 'to', l.effective_to) into v_long
    from public.teacher_long_leaves l join public.academic_years ay on ay.id = l.academic_year_id and ay.is_active
   where l.teacher_id = tid and l.renewal_status = 'renewed' order by l.effective_to desc nulls first limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'type', r.leave_type, 'from', r.date_from, 'to', r.date_to, 'notes', r.notes,
           'status', r.status, 'review_note', r.review_note, 'source', r.source, 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
    into v_req from (select * from public.teacher_long_leave_requests where teacher_id = tid order by created_at desc limit 20) r;
  return jsonb_build_object('ok', true, 'open', v_open, 'name', t.full_name, 'applies', t.work_type::text = 'permanent',
    'casual', jsonb_build_object('year_start', c_start, 'limit', 7, 'used', c_used, 'remaining', greatest(7 - c_used, 0)),
    'annual', jsonb_build_object('year_start', a_start, 'limit', a_lim, 'used', a_used, 'remaining', a_lim - a_used, 'over', a_used > a_lim,
       'grade_missing', coalesce(btrim(t.job_title),'') not in ('معلم مساعد','معلم','معلم أول','معلم أول (أ)','معلم أول أ','معلم خبير','كبير معلمين')),
    'short', v_short, 'long', v_long, 'requests', v_req);
end $$;

create or replace function public.teacher_portal_short_leave_add(p_civil text, p_phone text, p_teacher_id uuid, p_type text, p_from date, p_to date, p_notes text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_temp as $$
declare x jsonb; tid uuid; v_open boolean; v_id uuid; v_days int; a_lim int; a_used int; v_job text;
begin
  x := private.v423_ctx(p_civil, p_phone, p_teacher_id);
  if not (x ->> 'ok')::boolean then return x; end if;
  tid := (x ->> 'teacher_id')::uuid;
  select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if p_type not in ('عارضة','اعتيادي') or p_from is null or p_to is null or p_to < p_from or p_from < date '2020-01-01'
     or p_to > current_date + 366 or length(coalesce(p_notes,'')) > 300 then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  begin
    insert into public.teacher_short_leaves(teacher_id, leave_type, date_from, date_to, notes, source)
    values (tid, p_type, p_from, p_to, nullif(btrim(coalesce(p_notes,'')), ''), x ->> 'source')
    returning id, days into v_id, v_days;
  exception when sqlstate 'P0001' then
    return jsonb_build_object('ok', false, 'reason', 'rejected', 'message', sqlerrm);
  end;
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
  values ((x ->> 'role')::app_role, 'teacher_portal_short_leave_add', 'teacher', tid::text, null,
          jsonb_build_object('leave_id', v_id, 'type', p_type, 'from', p_from, 'to', p_to, 'days', v_days, 'by_teacher_id', x ->> 'by', 'source', x ->> 'source'));
  select job_title into v_job from public.teacher_records where id = tid;
  a_lim := private.v421_annual_limit(v_job);
  select coalesce(sum(days),0) into a_used from public.teacher_short_leaves
   where teacher_id = tid and leave_type = 'اعتيادي' and year_start = private.v421_year_start('اعتيادي', p_from) and cancelled_at is null;
  return jsonb_build_object('ok', true, 'id', v_id, 'days', v_days,
    'warning', case when p_type = 'اعتيادي' and a_used > a_lim then 'تجاوز رصيد الاعتيادي: المستخدم ' || a_used || ' من ' || a_lim || ' يومًا.' end);
end $$;

create or replace function public.teacher_portal_short_leave_cancel(p_civil text, p_phone text, p_teacher_id uuid, p_leave_id uuid)
returns jsonb language plpgsql security definer set search_path = public, private, pg_temp as $$
declare x jsonb; tid uuid; v_open boolean; s record;
begin
  x := private.v423_ctx(p_civil, p_phone, p_teacher_id);
  if not (x ->> 'ok')::boolean then return x; end if;
  tid := (x ->> 'teacher_id')::uuid;
  select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  select * into s from public.teacher_short_leaves where id = p_leave_id and teacher_id = tid for update;
  if s.id is null or s.cancelled_at is not null then return jsonb_build_object('ok', false, 'reason', 'gone'); end if;
  if s.source not in ('portal_teacher','portal_sup') or s.date_from <= current_date then
    return jsonb_build_object('ok', false, 'reason', 'rejected', 'message', 'لا يمكن إلغاء إجازة بدأت أو سُجّلت من البرنامج الرئيسي؛ تواصل مع موجهك.');
  end if;
  update public.teacher_short_leaves set cancelled_at = now() where id = s.id;
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
  values ((x ->> 'role')::app_role, 'teacher_portal_short_leave_cancel', 'teacher', tid::text,
          jsonb_build_object('leave_id', s.id, 'type', s.leave_type, 'from', s.date_from, 'to', s.date_to, 'days', s.days),
          jsonb_build_object('by_teacher_id', x ->> 'by', 'source', x ->> 'source'));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.teacher_portal_long_leave_request(p_civil text, p_phone text, p_teacher_id uuid, p_type text, p_from date, p_to date, p_notes text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_temp as $$
declare x jsonb; tid uuid; v_open boolean; v_id uuid;
begin
  x := private.v423_ctx(p_civil, p_phone, p_teacher_id);
  if not (x ->> 'ok')::boolean then return x; end if;
  tid := (x ->> 'teacher_id')::uuid;
  select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  if p_type not in ('إجازة وضع','رعاية طفل','مرافقة زوج أو زوجة','إجازة مرضية طويلة','إصابة عمل','رعاية أحد أفراد الأسرة','إجازة بدون مرتب','إجازة طويلة أخرى')
     or p_from is null or p_from < date '2020-01-01' or (p_to is not null and p_to < p_from) or length(coalesce(p_notes,'')) > 500 then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  if exists (select 1 from public.teacher_long_leave_requests r where r.teacher_id = tid and r.status = 'pending') then
    return jsonb_build_object('ok', false, 'reason', 'rejected', 'message', 'يوجد طلب إجازة طويلة بانتظار اعتماد الموجه؛ اسحبه أولًا إن أردت تعديله.');
  end if;
  insert into public.teacher_long_leave_requests(teacher_id, leave_type, date_from, date_to, notes, source, requested_by)
  values (tid, p_type, p_from, p_to, nullif(btrim(coalesce(p_notes,'')), ''), x ->> 'source', (x ->> 'by')::uuid)
  returning id into v_id;
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
  values ((x ->> 'role')::app_role, 'teacher_portal_long_leave_request', 'teacher', tid::text, null,
          jsonb_build_object('request_id', v_id, 'type', p_type, 'from', p_from, 'to', p_to, 'by_teacher_id', x ->> 'by', 'source', x ->> 'source'));
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

create or replace function public.teacher_portal_long_leave_withdraw(p_civil text, p_phone text, p_teacher_id uuid, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public, private, pg_temp as $$
declare x jsonb; tid uuid; r record;
begin
  x := private.v423_ctx(p_civil, p_phone, p_teacher_id);
  if not (x ->> 'ok')::boolean then return x; end if;
  tid := (x ->> 'teacher_id')::uuid;
  select * into r from public.teacher_long_leave_requests where id = p_request_id and teacher_id = tid for update;
  if r.id is null or r.status <> 'pending' then return jsonb_build_object('ok', false, 'reason', 'gone'); end if;
  update public.teacher_long_leave_requests set status = 'withdrawn', reviewed_at = now() where id = r.id;
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
  values ((x ->> 'role')::app_role, 'teacher_portal_long_leave_withdraw', 'teacher', tid::text, jsonb_build_object('request_id', r.id),
          jsonb_build_object('by_teacher_id', x ->> 'by', 'source', x ->> 'source'));
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.teacher_portal_leaves(text, text, uuid) from public;
revoke all on function public.teacher_portal_short_leave_add(text, text, uuid, text, date, date, text) from public;
revoke all on function public.teacher_portal_short_leave_cancel(text, text, uuid, uuid) from public;
revoke all on function public.teacher_portal_long_leave_request(text, text, uuid, text, date, date, text) from public;
revoke all on function public.teacher_portal_long_leave_withdraw(text, text, uuid, uuid) from public;
grant execute on function public.teacher_portal_leaves(text, text, uuid) to anon, authenticated;
grant execute on function public.teacher_portal_short_leave_add(text, text, uuid, text, date, date, text) to anon, authenticated;
grant execute on function public.teacher_portal_short_leave_cancel(text, text, uuid, uuid) to anon, authenticated;
grant execute on function public.teacher_portal_long_leave_request(text, text, uuid, text, date, date, text) to anon, authenticated;
grant execute on function public.teacher_portal_long_leave_withdraw(text, text, uuid, uuid) to anon, authenticated;
