-- v470: سد الوصول لأي حساب authenticated بلا دور (بنود 1–4 في function-audit.md)
-- لا تُشغَّل على الإنتاج إلا بعد: موافقة صريحة + pg_dump محدّث + مراجعة.
-- دورة حياة النسخة الاحتياطية: هذا الملف ينشئ private.v470_backup ويملؤه، ويرفض التشغيل إن كان موجودًا
-- (أي v470 مطبّق بالفعل). ملف الرجوع يعيد كل شيء من الجدول ثم يحذف سطر التدقيق الذي أضافه هذا الملف ثم يحذف الجدول،
-- فيصبح تطبيق → رجوع → تطبيق ممكنًا بلا تعارض.
begin;

do $$ begin
  if to_regclass('private.v470_backup') is not null then
    raise exception 'v470: مطبّق بالفعل (private.v470_backup موجود) — شغّل ملف الرجوع أولًا' using errcode = 'V4701';
  end if;
  if (select atttypid from pg_attribute where attrelid = 'public.audit_log'::regclass and attname = 'id') <> 'bigint'::regtype then
    raise exception 'v470: audit_log.id ليس bigint — توقف' using errcode = 'V4703';
  end if;
end $$;

-- 0) نسخة احتياطية حرفية من كل ما سيتغير
create table private.v470_backup(
  kind text not null, name text not null, def text, extra text, saved_at timestamptz not null default now(),
  primary key (kind, name));
revoke all on private.v470_backup from public, anon, authenticated;

insert into private.v470_backup(kind, name, def) values
 ('view',     'public.teacher_workload_summary',   pg_get_viewdef('public.teacher_workload_summary'::regclass)),
 ('function', 'public.lookup_identity_by_civil(text)', pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure));
insert into private.v470_backup(kind, name, def, extra)
 select 'policy', schemaname||'.'||tablename||'.'||policyname, qual, with_check
 from pg_policies
 where (schemaname, tablename, policyname) in (('public','school_supervisor_choice','ssc_read'), ('public','audit_log','audit_insert'));
do $$ begin
  if (select count(*) from private.v470_backup) <> 4 then raise exception 'v470: النسخة الاحتياطية ناقصة — توقف'; end if;
end $$;

-- 1) البند 1 (عالي): teacher_workload_summary — شرط وجود الدور يلف الطرفين:
--    WHERE (role IS NOT NULL) AND ((role IS DISTINCT FROM 'teacher') OR (profile_id = auth.uid()))
--    teacher_official_staffing عرض security_invoker يقرأ منه فيُصلَح تبعًا.
do $$ declare d text;
  old text := '((( SELECT private.current_app_role() AS current_app_role) IS DISTINCT FROM ''teacher''::app_role) OR (profile_id = ( SELECT auth.uid() AS uid)))';
  new text := '((( SELECT private.current_app_role() AS current_app_role) IS NOT NULL) AND ' || old || ')';
begin
  d := pg_get_viewdef('public.teacher_workload_summary'::regclass);
  if (length(d) - length(replace(d, old, ''))) / length(old) <> 1 then
    raise exception 'v470: شرط العرض ليس موجودًا مرة واحدة بالضبط — توقف'; end if;
  execute 'create or replace view public.teacher_workload_summary as ' || replace(d, old, new);
end $$;

-- 2) البند 2 (متوسط): school_supervisor_choice — القراءة لمن له دور فقط
alter policy ssc_read on public.school_supervisor_choice
  using ((select private.current_app_role()) is not null);

-- 3) البند 3 (متوسط): lookup_identity_by_civil — الأدوار التي تستعملها الشاشات فقط:
--    admin (إنشاء حساب)، stage_coordinator وsupervisor (إنشاء حساب/إضافة معلم سريعة)، senior_teacher «حساب المدرسة»
--    (إضافة معلمين بسرعة seniorTeacherAddTeacherForm). غير ذلك (teacher، first_supervisor، school_manager، بلا دور) ← غير صالح.
do $$ declare d text;
begin
  d := pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure);
  if d !~* 'language plpgsql' then raise exception 'v470: الدالة ليست plpgsql — توقف'; end if;
  if d !~* E'\\nbegin\\n' then raise exception 'v470: لم يوجد begin في الدالة — توقف'; end if;
  d := regexp_replace(d, E'\\nbegin\\n',
    E'\nbegin\n  -- v470: الأدوار المسموحة = admin, stage_coordinator, supervisor (جدول المراجعة) + senior_teacher عمدًا:\n  -- «حساب المدرسة» يستعمل هذه الدالة في شاشة «إضافة معلمين بسرعة» (index.html: seniorTeacherAddTeacherForm ← uxSmartifyForm ← uxLookupCivil).\n  if coalesce((select private.current_app_role())::text, '''') not in (''admin'',''stage_coordinator'',''supervisor'',''senior_teacher'') then return jsonb_build_object(''valid'', false, ''exists'', false); end if; -- v470\n', 'i');
  execute d;
end $$;

-- 4) البند 4 (منخفض): audit_insert — هوية صحيحة + دور
alter policy audit_insert on public.audit_log
  with check (actor_profile_id = (select auth.uid()) and (select private.current_app_role()) is not null);

-- تحقق داخلي
do $$ begin
  if pg_get_viewdef('public.teacher_workload_summary'::regclass) not like '%IS NOT NULL) AND%' then raise exception 'v470: العرض لم يتغير'; end if;
  if pg_get_functiondef('public.lookup_identity_by_civil(text)'::regprocedure) not like '%-- v470%' then raise exception 'v470: الدالة لم تتغير'; end if;
end $$;

-- سطر تدقيق واحد ويُسجَّل معرّفه ليحذفه الرجوع وحده
with a as (
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
  values ('admin', 'v470_close_roleless_access', 'security', 'v470', null,
          jsonb_build_object('items', 'teacher_workload_summary,ssc_read,lookup_identity_by_civil,audit_insert'))
  returning id)
insert into private.v470_backup(kind, name, def) select 'audit', 'apply_row', id::text from a;
commit;
