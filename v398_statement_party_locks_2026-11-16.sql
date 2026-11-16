-- v398: قفل رفع صحائف الأحوال منفصل للمنسق وللمعلم (لكل مرحلة).
-- قبل: مفتاح واحد لكل مرحلة (statement_stage_settings.is_open) يحكم المعلم في البوابة والمنسق معًا.
-- بعد: is_open = قفل المعلم (البوابة) بلا تغيير في أي دالة تقرؤه، وعمود جديد coordinator_open = قفل المنسق.
-- القيمة الابتدائية لقفل المنسق = حالة المفتاح الحالية فلا يتغير سلوك أي أحد عند التطبيق.

-- 1) نسخ احتياطية (لا تُحذف؛ يعتمد عليها ملف الاسترجاع)
create table if not exists private.v398_backup_settings as select * from public.statement_stage_settings;
create table if not exists private.v398_backup_functions as
select p.proname::text as proname, pg_get_functiondef(p.oid) as def
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('admin_statements_overview', 'coordinator_statements_overview', 'service_statement_coord_prepare');

-- 2) العمود الجديد (مرة واحدة فقط؛ يأخذ حالة المفتاح الحالية)
do $do$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'statement_stage_settings' and column_name = 'coordinator_open') then
    alter table public.statement_stage_settings add column coordinator_open boolean not null default false;
    update public.statement_stage_settings set coordinator_open = is_open where stage is not null;
  end if;
end $do$;

-- 3) ثلاث دوال تُعدَّل نصيًا مرة واحدة بالضبط (يفشل التطبيق إن لم يطابق النص مرة واحدة)
do $do$
declare r record; d text; n int;
begin
  for r in select * from (values
    ('public.admin_statements_overview()',
     $a$jsonb_build_object('stage', ss.stage, 'open', ss.is_open)$a$,
     $b$jsonb_build_object('stage', ss.stage, 'open', ss.is_open, 'coordinator_open', ss.coordinator_open)$b$),
    ('public.coordinator_statements_overview()',
     $a$jsonb_build_object('stage', ss.stage, 'open', ss.is_open)$a$,
     $b$jsonb_build_object('stage', ss.stage, 'open', ss.coordinator_open)$b$),
    ('public.service_statement_coord_prepare(uuid, uuid)',
     $a$select ss.is_open into v_open$a$,
     $b$select ss.coordinator_open into v_open$b$)
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(r.fn::regprocedure);
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception 'v398: عدد المطابقات % في %', n, r.fn; end if;
    execute replace(d, r.a, r.b);
  end loop;
end $do$;

-- 4) فتح/إغلاق الرفع لطرف بعينه في مرحلة (للمدير فقط)
create or replace function public.admin_set_statement_party(p_stage text, p_party text, p_open boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'pg_temp'
as $fn$
declare v_old boolean;
begin
  perform private.v356_require_admin();
  if coalesce(p_party, '') not in ('teacher', 'coordinator') then
    raise exception 'طرف غير معروف' using errcode = '22023';
  end if;
  select case when p_party = 'teacher' then is_open else coordinator_open end into v_old
    from public.statement_stage_settings where stage = p_stage;
  if not found then raise exception 'مرحلة غير معروفة' using errcode = '22023'; end if;
  if p_party = 'teacher' then
    update public.statement_stage_settings set is_open = coalesce(p_open, false), updated_at = now() where stage = p_stage;
  else
    update public.statement_stage_settings set coordinator_open = coalesce(p_open, false), updated_at = now() where stage = p_stage;
  end if;
  insert into public.audit_log (actor_profile_id, actor_role, action, entity_type, entity_id, old_data, new_data)
  values (auth.uid(), 'admin', 'statement_stage_toggle', 'statement_stage', p_stage,
          jsonb_build_object('party', p_party, 'open', v_old),
          jsonb_build_object('party', p_party, 'open', coalesce(p_open, false)));
  return jsonb_build_object('ok', true, 'stage', p_stage, 'party', p_party, 'open', coalesce(p_open, false));
end $fn$;
revoke all on function public.admin_set_statement_party(text, text, boolean) from public, anon;
grant execute on function public.admin_set_statement_party(text, text, boolean) to authenticated, service_role;
