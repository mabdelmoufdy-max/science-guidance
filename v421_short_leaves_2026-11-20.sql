-- v421: الإجازات القصيرة (عارضة/اعتيادي) ورصيدها — المرحلة 3 من خطة الإجازات (2026-11-20)
-- قرارات المستخدم: للمعلم الأساسي فقط؛ تُحسب أيام العمل (بلا الجمعة)؛ العارضة 7 أيام سنتها 1/7–30/6 ويُمنع الحفظ بعدها؛
-- الاعتيادي سنته 1/9–31/8 وحدّه بالدرجة (مساعد 30، معلم/أول/أول أ 35، خبير 40، كبير معلمين 45، غير مسجلة 35 مع تنبيه) وتجاوزه تنبيه فقط.
-- لا تلغي إسنادًا ولا إشرافًا. الكتابة بدوال لاحقة (المرحلة 4)؛ لا صلاحيات مباشرة على الجدول.
create table if not exists public.teacher_short_leaves (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null,
  leave_type text not null check (leave_type in ('عارضة','اعتيادي')),
  date_from date not null,
  date_to date not null,
  days int not null default 0,
  year_start date not null default current_date,
  notes text,
  source text not null default 'program' check (source in ('program','portal_teacher','portal_sup')),
  created_by uuid,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid,
  constraint teacher_short_leaves_dates check (date_to >= date_from)
);
create index if not exists teacher_short_leaves_teacher_idx on public.teacher_short_leaves(teacher_id, leave_type, year_start);
alter table public.teacher_short_leaves enable row level security;
revoke all on public.teacher_short_leaves from anon, authenticated;

create or replace function private.v421_workdays(p_from date, p_to date) returns int
language sql immutable set search_path = pg_catalog as $$
  select count(*)::int from generate_series(p_from, p_to, interval '1 day') d where extract(dow from d) <> 5
$$;

create or replace function private.v421_year_start(p_type text, p_d date) returns date
language sql immutable set search_path = pg_catalog as $$
  select case when p_type = 'عارضة'
    then make_date(extract(year from p_d)::int - case when extract(month from p_d) < 7 then 1 else 0 end, 7, 1)
    else make_date(extract(year from p_d)::int - case when extract(month from p_d) < 9 then 1 else 0 end, 9, 1) end
$$;

create or replace function private.v421_annual_limit(p_job text) returns int
language sql immutable set search_path = pg_catalog as $$
  select case btrim(coalesce(p_job,''))
    when 'معلم مساعد' then 30 when 'معلم' then 35 when 'معلم أول' then 35 when 'معلم أول (أ)' then 35 when 'معلم أول أ' then 35
    when 'معلم خبير' then 40 when 'كبير معلمين' then 45 else 35 end
$$;

create or replace function private.v421_guard() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare t record; v_used int;
begin
  if new.cancelled_at is not null then return new; end if;
  select id, work_type, active into t from public.teacher_records where id = new.teacher_id;
  if t.id is null or not t.active then raise exception 'المعلم غير موجود أو غير نشط.' using errcode = 'P0001'; end if;
  if t.work_type::text <> 'permanent' then raise exception 'الإجازات القصيرة للمعلم الأساسي فقط.' using errcode = 'P0001'; end if;
  new.year_start := private.v421_year_start(new.leave_type, new.date_from);
  if private.v421_year_start(new.leave_type, new.date_to) <> new.year_start then
    raise exception 'الإجازة تتخطى بداية سنة % الجديدة؛ سجّلها فترتين.', new.leave_type using errcode = 'P0001';
  end if;
  new.days := private.v421_workdays(new.date_from, new.date_to);
  if new.days < 1 then raise exception 'الفترة لا تحتوي يوم عمل (الجمعة لا تُحتسب).' using errcode = 'P0001'; end if;
  if exists (select 1 from public.teacher_short_leaves s where s.teacher_id = new.teacher_id and s.cancelled_at is null
             and s.id <> new.id and s.date_from <= new.date_to and s.date_to >= new.date_from) then
    raise exception 'توجد إجازة قصيرة مسجلة تتداخل مع هذه الفترة.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.teacher_long_leaves l where l.teacher_id = new.teacher_id and l.renewal_status = 'renewed'
             and coalesce(l.effective_from, '-infinity'::date) <= new.date_to and coalesce(l.effective_to, 'infinity'::date) >= new.date_from) then
    raise exception 'المعلم في إجازة طويلة خلال هذه الفترة.' using errcode = 'P0001';
  end if;
  if new.leave_type = 'عارضة' then
    select coalesce(sum(days),0) into v_used from public.teacher_short_leaves s
     where s.teacher_id = new.teacher_id and s.leave_type = 'عارضة' and s.year_start = new.year_start and s.cancelled_at is null and s.id <> new.id;
    if v_used + new.days > 7 then
      raise exception 'رصيد العارضة 7 أيام في السنة؛ المستخدم % ويتبقى % فقط.', v_used, greatest(7 - v_used, 0) using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
revoke all on function private.v421_guard() from public, anon, authenticated;
create trigger trg_v421_short_leave_guard before insert or update on public.teacher_short_leaves
  for each row execute function private.v421_guard();

-- الرصيد: لمن يملك الوصول للمعلم فقط
create or replace function public.teacher_short_leave_balance(p_teacher_id uuid, p_on date default current_date) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare t record; c_start date; a_start date; c_used int; a_used int; a_lim int;
begin
  if auth.uid() is null or not private.can_access_teacher(p_teacher_id) then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  select id, work_type, job_title into t from public.teacher_records where id = p_teacher_id;
  if t.id is null then raise exception 'المعلم غير موجود' using errcode = 'P0001'; end if;
  c_start := private.v421_year_start('عارضة', p_on);
  a_start := private.v421_year_start('اعتيادي', p_on);
  select coalesce(sum(days),0) into c_used from public.teacher_short_leaves where teacher_id = p_teacher_id and leave_type = 'عارضة' and year_start = c_start and cancelled_at is null;
  select coalesce(sum(days),0) into a_used from public.teacher_short_leaves where teacher_id = p_teacher_id and leave_type = 'اعتيادي' and year_start = a_start and cancelled_at is null;
  a_lim := private.v421_annual_limit(t.job_title);
  return jsonb_build_object(
    'applies', t.work_type::text = 'permanent',
    'casual', jsonb_build_object('year_start', c_start, 'year_end', (c_start + interval '1 year' - interval '1 day')::date, 'limit', 7, 'used', c_used, 'remaining', greatest(7 - c_used, 0)),
    'annual', jsonb_build_object('year_start', a_start, 'year_end', (a_start + interval '1 year' - interval '1 day')::date, 'limit', a_lim, 'used', a_used, 'remaining', a_lim - a_used,
       'over', a_used > a_lim, 'grade_missing', private.v421_annual_limit(t.job_title) = 35 and coalesce(btrim(t.job_title),'') not in ('معلم','معلم أول','معلم أول (أ)','معلم أول أ')));
end $$;
revoke all on function public.teacher_short_leave_balance(uuid, date) from public, anon;
grant execute on function public.teacher_short_leave_balance(uuid, date) to authenticated;
