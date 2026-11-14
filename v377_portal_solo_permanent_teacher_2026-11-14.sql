-- v377: المعلم الأساسي الوحيد في مدرسته (work_type=permanent، نشط، مدرسته الأصلية) يدخل البوابة بدور المدرسة ولو لم يكن مشرف مادة ولا مسؤول بيانات.
-- يتبع نفس تحقق مشرف المدرسة (private.tp_sup_view_check) فيشمل: معلمي المدرسة، جدول المعلم، الفصول والمجموعات (إسناد/إلغاء). لا تعديل لبقية الدوال.
-- الاستبدال النصي مرة واحدة بالضبط (يفشل إن لم يطابق)؛ نسخة الدوال قبل التعديل في private.v377_backup_functions (لا تُحذف).
create table if not exists private.v377_backup_functions as
  select p.oid::regprocedure::text as sig, pg_get_functiondef(p.oid) as def
    from pg_proc p
   where p.oid in ('private.tp_sup_view_check(text,text,text)'::regprocedure, 'public.teacher_portal_login(text,text)'::regprocedure);

create or replace function private.v377_solo_permanent(p_teacher uuid)
returns boolean language sql stable security definer
set search_path to 'pg_catalog','public','pg_temp'
as $f$
  select exists (
    select 1 from public.teacher_records t
     where t.id = p_teacher and t.active and t.work_type = 'permanent' and t.home_school_id is not null
       and 1 = (select count(*) from public.teacher_records z
                 where z.active and z.work_type = 'permanent' and z.home_school_id = t.home_school_id))
$f$;
revoke all on function private.v377_solo_permanent(uuid) from public, anon, authenticated;

do $do$
declare d text; a text; b text; fn text; i int;
  pairs text[][] := array[
    array['private.tp_sup_view_check(text,text,text)',
          'case when t.is_senior_teacher and t.home_school_id is not null then t.home_school_id else o.school_id end,',
          'case when t.is_senior_teacher and t.home_school_id is not null then t.home_school_id else coalesce(o.school_id, t.home_school_id) end,'],
    array['private.tp_sup_view_check(text,text,text)',
          $$case when t.is_senior_teacher and t.home_school_id is not null then 'sup' else 'officer' end$$,
          $$case when t.is_senior_teacher and t.home_school_id is not null then 'sup' when o.teacher_id is not null then 'officer' else 'solo' end$$],
    array['private.tp_sup_view_check(text,text,text)',
          'and ((t.is_senior_teacher and t.home_school_id is not null) or o.teacher_id is not null)',
          'and ((t.is_senior_teacher and t.home_school_id is not null) or o.teacher_id is not null or private.v377_solo_permanent(t.id))'],
    array['public.teacher_portal_login(text,text)',
          'v_off boolean := false;',
          'v_off boolean := false; v_solo boolean := false;'],
    array['public.teacher_portal_login(text,text)',
          'select exists(select 1 from public.school_data_officer o where o.teacher_id = (c ->> ''teacher_id'')::uuid) into v_off;',
          'select exists(select 1 from public.school_data_officer o where o.teacher_id = (c ->> ''teacher_id'')::uuid) into v_off; if not v_off then v_solo := private.v377_solo_permanent((c ->> ''teacher_id'')::uuid); end if;'],
    array['public.teacher_portal_login(text,text)',
          $$'is_sup', v_sup or v_off, 'sup_kind', case when v_sup then 'sup' when v_off then 'officer' end,$$,
          $$'is_sup', v_sup or v_off or v_solo, 'sup_kind', case when v_sup then 'sup' when v_off then 'officer' when v_solo then 'solo' end,$$]
  ];
begin
  for fn in select distinct pairs[k][1] from generate_subscripts(pairs, 1) k loop
    d := pg_get_functiondef(fn::regprocedure);
    for i in 1 .. array_length(pairs, 1) loop
      if pairs[i][1] = fn then
        a := pairs[i][2]; b := pairs[i][3];
        if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'v377: النص لا يطابق مرة واحدة (%): %', fn, left(a, 60); end if;
        d := replace(d, a, b);
      end if;
    end loop;
    execute d;
  end loop;
end $do$;
