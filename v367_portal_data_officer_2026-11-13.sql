-- v367: مسؤول بيانات المدرسة (school_data_officer) يدخل بوابة المعلمين مثل المشرف: يختار «معلم» أو «مسؤول البيانات» ويرى معلمي المدرسة المعيّن لها ويُدخل جداولهم (بقرار المستخدم ١أ ٢ب).
create or replace function private.tp_sup_view_check(p_civil text, p_phone text, p_code text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $function$
declare
  v_civil text := private.tp_digits(p_civil);
  v_phone text := right(private.tp_digits(p_phone), 10);
  v_tid uuid; v_name text; v_school uuid; v_kind text;
  v_fail int; v_fifth timestamptz; v_glob int;
begin
  if v_civil !~ '^[0-9]{14}$' then return jsonb_build_object('status','bad_civil'); end if;
  if v_phone !~ '^1[0125][0-9]{8}$' then return jsonb_build_object('status','bad_phone'); end if;

  select count(*), (array_agg(created_at order by created_at desc))[5]
    into v_fail, v_fifth
    from public.teacher_portal_attempts
   where civil_id = v_civil and not ok and created_at > now() - interval '15 minutes';
  if v_fail >= 5 then
    return jsonb_build_object('status','locked',
      'minutes', greatest(1, ceil(extract(epoch from (v_fifth + interval '15 minutes' - now())) / 60)::int));
  end if;

  select count(*) into v_glob from public.teacher_portal_attempts
   where not ok and created_at > now() - interval '10 minutes';
  if v_glob > 600 then return jsonb_build_object('status','busy'); end if;

  -- مشرف المدرسة (مدرسته الأصلية) أو مسؤول بيانات المدرسة المعيّن لها (v367)
  select t.id, t.full_name,
         case when t.is_senior_teacher and t.home_school_id is not null then t.home_school_id else o.school_id end,
         case when t.is_senior_teacher and t.home_school_id is not null then 'sup' else 'officer' end
    into v_tid, v_name, v_school, v_kind
    from public.teacher_records t
    left join public.school_data_officer o on o.teacher_id = t.id
   where t.civil_id = v_civil and t.active
     and right(private.tp_digits(t.phone), 10) = v_phone
     and ((t.is_senior_teacher and t.home_school_id is not null) or o.teacher_id is not null)
   order by t.is_senior_teacher desc
   limit 1;

  if v_tid is null then
    insert into public.teacher_portal_attempts(civil_id, ok, reason) values (v_civil, false, 'sup_no_match');
    return jsonb_build_object('status','no_match','remaining', greatest(0, 4 - v_fail));
  end if;

  delete from public.teacher_portal_attempts where civil_id = v_civil and not ok;
  return jsonb_build_object('status','ok','school_id', v_school, 'teacher_id', v_tid, 'name', v_name, 'kind', v_kind);
end $function$;

create or replace function public.teacher_portal_login(p_civil text, p_phone text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare c jsonb; v_sup boolean := false; v_off boolean := false;
begin
  c := private.tp_check(p_civil, p_phone);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['teacher_id','status','limited']);
  end if;
  if not coalesce((c ->> 'limited')::boolean, false) then
    select exists(select 1 from public.teacher_records t
      where t.id = (c ->> 'teacher_id')::uuid and t.active and t.is_senior_teacher and t.home_school_id is not null)
      into v_sup;
    if not v_sup then
      select exists(select 1 from public.school_data_officer o where o.teacher_id = (c ->> 'teacher_id')::uuid) into v_off;
    end if;
  end if;
  return jsonb_build_object('ok', true, 'is_sup', v_sup or v_off, 'sup_kind', case when v_sup then 'sup' when v_off then 'officer' end,
    'limited', coalesce((c ->> 'limited')::boolean, false));
end $f$;
revoke all on function public.teacher_portal_login(text,text) from public;
grant execute on function public.teacher_portal_login(text,text) to anon, authenticated;
