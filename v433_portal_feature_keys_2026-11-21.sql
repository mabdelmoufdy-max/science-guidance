-- v433: «مفاتيح البوابة» — سجل مركزي يتحكم في كل وظائف بوابة المعلمين (معلم/مشرف × وظيفة × مرحلة) + جدولة + أوضاع جاهزة.
-- الافتراضي: كل المفاتيح بقيمها الحالية (لا تغيير في سلوك أي مستخدم). الأعمدة القديمة في teacher_portal_settings تبقى مرايا للمفتاح العام.

-- ===== 1) الجداول =====
create table if not exists public.portal_feature_catalog (
  feature text primary key,
  label text not null,
  descr text,
  roles text[] not null,
  sort int not null default 0,
  external boolean not null default false
);
create table if not exists public.portal_feature_flags (
  feature text not null references public.portal_feature_catalog(feature),
  role text not null default 'all' check (role in ('all','teacher','supervisor')),
  stage text not null default 'all' check (stage in ('all','ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي')),
  is_open boolean not null default true,
  message text check (message is null or length(message) <= 200),
  updated_by uuid,
  updated_at timestamptz not null default now(),
  primary key (feature, role, stage)
);
create table if not exists public.portal_feature_schedule (
  id uuid primary key default gen_random_uuid(),
  feature text not null references public.portal_feature_catalog(feature),
  role text not null default 'all' check (role in ('all','teacher','supervisor')),
  stage text not null default 'all' check (stage in ('all','ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي')),
  value boolean not null,
  run_at timestamptz not null,
  reason text,
  created_by uuid,
  created_at timestamptz not null default now(),
  done_at timestamptz,
  cancelled_at timestamptz,
  result text
);
alter table public.portal_feature_catalog enable row level security;
alter table public.portal_feature_flags enable row level security;
alter table public.portal_feature_schedule enable row level security;
revoke all on public.portal_feature_catalog, public.portal_feature_flags, public.portal_feature_schedule from anon, authenticated;

insert into public.portal_feature_catalog(feature, label, descr, roles, sort, external) values
 ('editing','تسجيل وتعديل البيانات','إرسال البيانات الأساسية من البوابة (معلم جديد/تعديل)', '{teacher,supervisor}', 10, false),
 ('fill','إكمال البيانات الناقصة','إضافة الحقول الفارغة في «بياناتي» وفي بيانات معلمي المدرسة', '{teacher,supervisor}', 20, false),
 ('paid_ws','تعديل تاريخ استلام عمل الأجر','تعديل التاريخ المسجّل لمعلم الأجر', '{teacher}', 30, false),
 ('timetable','إدخال الجدول الأسبوعي','المعلم يدخل جدوله، والمشرف يضع جدول معلمي مدرسته', '{teacher,supervisor}', 40, false),
 ('leaves_short','الإجازات القصيرة','تسجيل العارضة والاعتيادي وإلغاؤها', '{teacher,supervisor}', 50, false),
 ('leaves_long','طلب الإجازة الطويلة','تقديم طلب إجازة طويلة بانتظار اعتماد الموجه', '{teacher,supervisor}', 60, false),
 ('assign','إسناد وإلغاء إسناد الفصول','المشرف يسند المعلمين للفصول أو يلغي الإسناد', '{supervisor}', 70, false),
 ('classes','إضافة وحذف الفصول والمجموعات','المشرف يضيف أو يحذف فصلًا غير مسند', '{supervisor}', 80, false),
 ('school_edit','بيانات المدرسة','المشرف يعدّل هاتف المدرسة وعنوانها وبيانات المدير', '{supervisor}', 90, false),
 ('statement','رفع صحيفة الأحوال','يُدار لكل مرحلة من شاشة «صحائف الأحوال»/هنا بمفتاحي المعلم والمنسق', '{teacher}', 100, true)
on conflict (feature) do nothing;

-- المفتاح العام لكل وظيفة = قيمته الحالية في الأعمدة القديمة
insert into public.portal_feature_flags(feature, role, stage, is_open)
select f.feature, 'all', 'all', f.v from (
  select 'editing' feature, coalesce(editing_open,true) v from public.teacher_portal_settings where id=1
  union all select 'fill', coalesce(fill_open,true) from public.teacher_portal_settings where id=1
  union all select 'paid_ws', coalesce(paid_ws_edit_open,true) from public.teacher_portal_settings where id=1
  union all select 'timetable', coalesce(timetable_open,true) from public.teacher_portal_settings where id=1
  union all select 'leaves_short', coalesce(leaves_open,true) from public.teacher_portal_settings where id=1
  union all select 'leaves_long', coalesce(leaves_open,true) from public.teacher_portal_settings where id=1
  union all select 'assign', coalesce(assign_open,true) from public.teacher_portal_settings where id=1
  union all select 'classes', coalesce(classes_open,true) from public.teacher_portal_settings where id=1
  union all select 'school_edit', coalesce(school_edit_open,true) from public.teacher_portal_settings where id=1
) f
on conflict do nothing;

-- ===== 2) الدوال الداخلية =====
create or replace function private.pf_open(p_feature text, p_role text, p_school uuid, p_teacher uuid)
returns boolean language sql stable security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
  with st as (
    select coalesce(
      (select s.stage from public.schools s where s.id = p_school),
      (select s.stage from public.teacher_records t join public.schools s on s.id = t.home_school_id where t.id = p_teacher)) as stage)
  select not exists (
    select 1 from public.portal_feature_flags f, st
    where f.feature = p_feature and not f.is_open
      and f.role in ('all', p_role) and (f.stage = 'all' or f.stage = st.stage));
$f$;
create or replace function private.pf_open_civil(p_feature text, p_role text, p_civil text)
returns boolean language sql stable security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
  select private.pf_open(p_feature, p_role, null,
    (select t.id from public.teacher_records t where t.civil_id = private.tp_digits(p_civil) limit 1));
$f$;
create or replace function private.pf_set(p_feature text, p_role text, p_stage text, p_open boolean, p_message text, p_set_message boolean)
returns void language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
begin
  insert into public.portal_feature_flags(feature, role, stage, is_open, message, updated_by, updated_at)
  values (p_feature, p_role, p_stage, coalesce(p_open, true), case when p_set_message then nullif(btrim(coalesce(p_message,'')),'') end, auth.uid(), now())
  on conflict (feature, role, stage) do update
    set is_open = excluded.is_open,
        message = case when p_set_message then excluded.message else public.portal_feature_flags.message end,
        updated_by = excluded.updated_by, updated_at = now();
end $f$;

-- مرآة المفتاح العام إلى الأعمدة القديمة (تقرؤها شاشات قديمة مثل lookup/صفحة الاعتماد)
create or replace function private.pf_mirror()
returns trigger language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
begin
  if new.role <> 'all' or new.stage <> 'all' then return new; end if;
  update public.teacher_portal_settings set
    editing_open = case when new.feature = 'editing' then new.is_open else editing_open end,
    fill_open = case when new.feature = 'fill' then new.is_open else fill_open end,
    paid_ws_edit_open = case when new.feature = 'paid_ws' then new.is_open else paid_ws_edit_open end,
    timetable_open = case when new.feature = 'timetable' then new.is_open else timetable_open end,
    assign_open = case when new.feature = 'assign' then new.is_open else assign_open end,
    classes_open = case when new.feature = 'classes' then new.is_open else classes_open end,
    school_edit_open = case when new.feature = 'school_edit' then new.is_open else school_edit_open end,
    leaves_open = case when new.feature in ('leaves_short','leaves_long')
        then coalesce((select bool_and(f.is_open) from public.portal_feature_flags f
                       where f.feature in ('leaves_short','leaves_long') and f.role = 'all' and f.stage = 'all'), true)
        else leaves_open end,
    updated_at = now()
  where id = 1;
  return new;
end $f$;

create or replace trigger trg_pf_mirror after insert or update on public.portal_feature_flags
  for each row execute function private.pf_mirror();

create or replace function private.run_portal_schedule()
returns int language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare r record; v_old boolean; n int := 0;
begin
  for r in select * from public.portal_feature_schedule
            where done_at is null and cancelled_at is null and run_at <= now()
            order by run_at, created_at for update skip locked loop
    select is_open into v_old from public.portal_feature_flags where feature = r.feature and role = r.role and stage = r.stage;
    perform private.pf_set(r.feature, r.role, r.stage, r.value, null, false);
    update public.portal_feature_schedule set done_at = now(), result = 'ok' where id = r.id;
    insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
    values (r.created_by, 'admin', 'cc_portal_feature_scheduled', 'portal_feature_flags', r.feature,
            jsonb_build_object('feature', r.feature, 'role', r.role, 'stage', r.stage, 'open', coalesce(v_old, true)),
            jsonb_build_object('feature', r.feature, 'role', r.role, 'stage', r.stage, 'open', r.value, 'schedule_id', r.id, 'reason', r.reason));
    n := n + 1;
  end loop;
  return n;
end $f$;
revoke all on function private.pf_open(text,text,uuid,uuid), private.pf_open_civil(text,text,text),
  private.pf_set(text,text,text,boolean,text,boolean), private.run_portal_schedule() from public;

-- ===== 3) الدوال العامة =====
-- للبوابة: المفاتيح المغلقة فقط (لا بيانات شخصية)
create or replace function public.teacher_portal_features()
returns jsonb language sql stable security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
  select jsonb_build_object('closed', coalesce((
    select jsonb_agg(jsonb_build_object('feature', f.feature, 'role', f.role, 'stage', f.stage, 'message', f.message))
    from public.portal_feature_flags f where not f.is_open), '[]'::jsonb));
$f$;

create or replace function public.admin_portal_features()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare v_actor uuid := private.v356_require_admin();
begin
  return jsonb_build_object(
    'catalog', (select coalesce(jsonb_agg(to_jsonb(c) order by c.sort), '[]'::jsonb) from public.portal_feature_catalog c),
    'flags', (select coalesce(jsonb_agg(jsonb_build_object('feature', f.feature, 'role', f.role, 'stage', f.stage, 'open', f.is_open,
                'message', f.message, 'updated_at', f.updated_at)), '[]'::jsonb) from public.portal_feature_flags f),
    'schedule', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'feature', s.feature, 'role', s.role, 'stage', s.stage,
                'value', s.value, 'run_at', s.run_at, 'reason', s.reason) order by s.run_at), '[]'::jsonb)
                 from public.portal_feature_schedule s where s.done_at is null and s.cancelled_at is null),
    'statements', (select coalesce(jsonb_agg(jsonb_build_object('stage', ss.stage, 'teacher_open', ss.is_open, 'coordinator_open', ss.coordinator_open)
                order by case ss.stage when 'ابتدائي' then 1 when 'إعدادي' then 2 when 'ثانوي عام' then 3 else 4 end), '[]'::jsonb)
                from public.statement_stage_settings ss),
    'impact', (select coalesce(jsonb_object_agg(x.stage, jsonb_build_object('teachers', x.teachers, 'supervisors', x.sups)), '{}'::jsonb)
               from (select s.stage, count(*) filter (where t.work_type is distinct from 'paid') teachers,
                            count(*) filter (where t.is_senior_teacher) sups
                     from public.teacher_records t join public.schools s on s.id = t.home_school_id
                     where t.active group by s.stage) x),
    'recent', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'at', a.created_at, 'action', a.action,
                'old', a.old_data, 'new', a.new_data, 'by', (select p.full_name from public.profiles p where p.id = a.actor_profile_id))
                order by a.id desc), '[]'::jsonb)
               from (select * from public.audit_log where action in ('cc_portal_feature','cc_portal_preset','cc_portal_feature_scheduled')
                     order by id desc limit 15) a));
end $f$;

create or replace function public.admin_set_portal_feature(p_feature text, p_role text, p_stage text, p_open boolean, p_message text default null, p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare v_actor uuid := private.v356_require_admin(); c public.portal_feature_catalog; o record; v_msg boolean := p_message is not null;
begin
  select * into c from public.portal_feature_catalog where feature = p_feature;
  if not found then raise exception 'وظيفة غير معروفة'; end if;
  if c.external then raise exception 'هذه الوظيفة تُدار من شاشة صحائف الأحوال'; end if;
  if p_role not in ('all') and not (p_role = any (c.roles)) then raise exception 'الدور غير مرتبط بهذه الوظيفة'; end if;
  if p_stage not in ('all','ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي') then raise exception 'مرحلة غير معروفة'; end if;
  if p_open is null then raise exception 'حدّد الحالة'; end if;
  select is_open, message into o from public.portal_feature_flags where feature = p_feature and role = p_role and stage = p_stage;
  perform private.pf_set(p_feature, p_role, p_stage, p_open, p_message, v_msg);
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_portal_feature', 'portal_feature_flags', p_feature,
          jsonb_build_object('feature', p_feature, 'role', p_role, 'stage', p_stage, 'open', coalesce(o.is_open, true), 'message', o.message),
          jsonb_build_object('feature', p_feature, 'role', p_role, 'stage', p_stage, 'open', p_open, 'message', nullif(btrim(coalesce(p_message,'')),''), 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true);
end $f$;

create or replace function public.admin_set_portal_preset(p_preset text, p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare v_actor uuid := private.v356_require_admin(); v_snap jsonb; v_n int := 0;
begin
  if p_preset not in ('view_only','open_all') then raise exception 'وضع غير معروف'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('feature', f.feature, 'role', f.role, 'stage', f.stage, 'open', f.is_open, 'message', f.message)), '[]'::jsonb)
    into v_snap from public.portal_feature_flags f
    join public.portal_feature_catalog c on c.feature = f.feature and not c.external;
  if p_preset = 'view_only' then
    perform private.pf_set(c.feature, 'all', 'all', false, null, false) from public.portal_feature_catalog c where not c.external;
  else
    update public.portal_feature_flags f set is_open = true, updated_by = auth.uid(), updated_at = now()
     where f.feature in (select c.feature from public.portal_feature_catalog c where not c.external) and not f.is_open;
  end if;
  get diagnostics v_n = row_count;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_portal_preset', 'portal_feature_flags', p_preset,
          jsonb_build_object('rows', v_snap), jsonb_build_object('preset', p_preset, 'reason', nullif(p_reason,'')));
  return jsonb_build_object('ok', true, 'preset', p_preset);
end $f$;

create or replace function public.admin_portal_schedule_add(p_feature text, p_role text, p_stage text, p_value boolean, p_run_at timestamptz, p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare v_actor uuid := private.v356_require_admin(); c public.portal_feature_catalog; v_id uuid;
begin
  select * into c from public.portal_feature_catalog where feature = p_feature;
  if not found or c.external then raise exception 'وظيفة غير صالحة للجدولة'; end if;
  if p_role not in ('all') and not (p_role = any (c.roles)) then raise exception 'الدور غير مرتبط بهذه الوظيفة'; end if;
  if p_stage not in ('all','ابتدائي','إعدادي','ثانوي عام','ثانوي صناعي') then raise exception 'مرحلة غير معروفة'; end if;
  if p_value is null or p_run_at is null then raise exception 'حدّد الحالة والموعد'; end if;
  if p_run_at <= now() then raise exception 'الموعد يجب أن يكون في المستقبل'; end if;
  if p_run_at > now() + interval '180 days' then raise exception 'الموعد أبعد من 180 يومًا'; end if;
  insert into public.portal_feature_schedule(feature, role, stage, value, run_at, reason, created_by)
  values (p_feature, p_role, p_stage, p_value, p_run_at, nullif(btrim(coalesce(p_reason,'')),''), v_actor) returning id into v_id;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_portal_schedule_add', 'portal_feature_schedule', v_id::text, null,
          jsonb_build_object('feature', p_feature, 'role', p_role, 'stage', p_stage, 'value', p_value, 'run_at', p_run_at));
  return jsonb_build_object('ok', true, 'id', v_id);
end $f$;
create or replace function public.admin_portal_schedule_cancel(p_id uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare v_actor uuid := private.v356_require_admin();
begin
  update public.portal_feature_schedule set cancelled_at = now() where id = p_id and done_at is null and cancelled_at is null;
  if not found then raise exception 'الجدولة غير موجودة أو نُفذت'; end if;
  insert into public.audit_log(actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'admin', 'cc_portal_schedule_cancel', 'portal_feature_schedule', p_id::text, null, null);
  return jsonb_build_object('ok', true);
end $f$;

revoke all on function public.teacher_portal_features(), public.admin_portal_features(),
  public.admin_set_portal_feature(text,text,text,boolean,text,text), public.admin_set_portal_preset(text,text),
  public.admin_portal_schedule_add(text,text,text,boolean,timestamptz,text), public.admin_portal_schedule_cancel(uuid) from public;
grant execute on function public.teacher_portal_features() to anon, authenticated;
grant execute on function public.admin_portal_features(), public.admin_set_portal_feature(text,text,text,boolean,text,text),
  public.admin_set_portal_preset(text,text), public.admin_portal_schedule_add(text,text,text,boolean,timestamptz,text),
  public.admin_portal_schedule_cancel(uuid) to authenticated;

-- ===== 4) ربط دوال البوابة بالسجل (استبدال نصي مرة واحدة لكل دالة، يفشل إن لم يطابق مرة واحدة بالضبط) =====
create or replace function private.v433_patch(p_name text, p_old text, p_new text)
returns void language plpgsql set search_path to 'pg_catalog','public','pg_temp' as $f$
declare v_oid oid; d text; n int;
begin
  select p.oid into strict v_oid from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = split_part(p_name, '.', 1) and p.proname = split_part(p_name, '.', 2);
  d := pg_get_functiondef(v_oid);
  n := (length(d) - length(replace(d, p_old, ''))) / length(p_old);
  if n <> 1 then raise exception 'v433_patch % : مطابقات % بدل 1', p_name, n; end if;
  execute replace(d, p_old, p_new);
end $f$;
revoke all on function private.v433_patch(text,text,text) from public;

select private.v433_patch('public.teacher_portal_fill_missing',
  'select coalesce(fill_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''fill'',''teacher'',null,(c ->> ''teacher_id'')::uuid);');
select private.v433_patch('public.teacher_portal_sup_fill_missing',
  'select coalesce(fill_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''fill'',''supervisor'',(c ->> ''school_id'')::uuid,null);');
select private.v433_patch('public.teacher_portal_paid_ws_set',
  'select coalesce(paid_ws_edit_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''paid_ws'',''teacher'',null,(c ->> ''teacher_id'')::uuid);');
select private.v433_patch('public.teacher_portal_timetable_save',
  'select coalesce(timetable_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''timetable'',''teacher'',null,(c ->> ''teacher_id'')::uuid);');
select private.v433_patch('public.teacher_portal_sup_timetable_save',
  'select coalesce(timetable_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''timetable'',''supervisor'',v_school,null);');
select private.v433_patch('public.teacher_portal_short_leave_add',
  'select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''leaves_short'', case when x ->> ''role'' = ''teacher'' then ''teacher'' else ''supervisor'' end, nullif(x ->> ''school_id'','''')::uuid, (x ->> ''teacher_id'')::uuid);');
select private.v433_patch('public.teacher_portal_short_leave_cancel',
  'select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''leaves_short'', case when x ->> ''role'' = ''teacher'' then ''teacher'' else ''supervisor'' end, nullif(x ->> ''school_id'','''')::uuid, (x ->> ''teacher_id'')::uuid);');
select private.v433_patch('public.teacher_portal_long_leave_request',
  'select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''leaves_long'', case when x ->> ''role'' = ''teacher'' then ''teacher'' else ''supervisor'' end, nullif(x ->> ''school_id'','''')::uuid, (x ->> ''teacher_id'')::uuid);');
select private.v433_patch('public.teacher_portal_sup_assign',
  'select coalesce(assign_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''assign'',''supervisor'',v_school,null);');
select private.v433_patch('public.teacher_portal_sup_unassign',
  'select coalesce(assign_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''assign'',''supervisor'',v_school,null);');
select private.v433_patch('public.teacher_portal_sup_add_class',
  'select coalesce(classes_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''classes'',''supervisor'',v_school,null);');
select private.v433_patch('public.teacher_portal_sup_remove_class',
  'select coalesce(classes_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''classes'',''supervisor'',v_school,null);');
select private.v433_patch('public.teacher_portal_sup_school_update',
  'select coalesce(school_edit_open, true) into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open(''school_edit'',''supervisor'',(c ->> ''school_id'')::uuid,null);');
select private.v433_patch('public.teacher_portal_submit',
  'select editing_open into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open_civil(''editing'',''teacher'',p_civil);');
select private.v433_patch('public.teacher_portal_sup_submit',
  'select editing_open into v_open from public.teacher_portal_settings where id = 1;',
  'v_open := private.pf_open_civil(''editing'',''supervisor'',p_civil);');

-- الكتّاب القدامى للمفتاحين (مركز التحكم v356، صفحة الاعتماد، الجدولة القديمة) يكتبون في السجل
select private.v433_patch('public.admin_set_flag',
  'update public.teacher_portal_settings set editing_open = p_value, updated_at = now() where id = 1;',
  'perform private.pf_set(''editing'',''all'',''all'',p_value,null,false);');
select private.v433_patch('public.admin_set_flag',
  'update public.teacher_portal_settings set timetable_open = p_value, updated_at = now() where id = 1;',
  'perform private.pf_set(''timetable'',''all'',''all'',p_value,null,false);');
select private.v433_patch('public.teacher_portal_admin_settings',
  'update public.teacher_portal_settings set editing_open = p_open, updated_at = now() where id = 1;',
  'perform private.pf_set(''editing'',''all'',''all'',p_open,null,false);');
select private.v433_patch('private.run_scheduled_flags',
  'update public.teacher_portal_settings set editing_open = r.value, updated_at = now() where id = 1;',
  'perform private.pf_set(''editing'',''all'',''all'',r.value,null,false);');
select private.v433_patch('private.run_scheduled_flags',
  'update public.teacher_portal_settings set timetable_open = r.value, updated_at = now() where id = 1;',
  'perform private.pf_set(''timetable'',''all'',''all'',r.value,null,false);');
select private.v433_patch('private.run_scheduled_flags',
  E'  return n;',
  E'  n := n + private.run_portal_schedule();\n  return n;');
-- التراجع من سجل التدقيق عن تغيير مفتاح/وضع جاهز
select private.v433_patch('public.admin_revert_action',
  E'  elsif a.action = ''cc_permissions'' then',
  E'  elsif a.action = ''cc_portal_feature'' then\n    perform public.admin_set_portal_feature(a.old_data->>''feature'', a.old_data->>''role'', a.old_data->>''stage'', coalesce((a.old_data->>''open'')::boolean, true), coalesce(a.old_data->>''message'', ''''), v_r);\n  elsif a.action = ''cc_portal_preset'' then\n    for e in select * from jsonb_array_elements(a.old_data->''rows'') loop\n      perform private.pf_set(e->>''feature'', e->>''role'', e->>''stage'', coalesce((e->>''open'')::boolean, true), e->>''message'', true);\n    end loop;\n  elsif a.action = ''cc_permissions'' then');
