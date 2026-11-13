-- v363: دخول موحد لبوابة المعلمين: تحقق واحد (tp_check) ويعيد هل المعلم مشرف مدرسة، بلا محاولة فاشلة إضافية.
create or replace function public.teacher_portal_login(p_civil text, p_phone text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare c jsonb; v_sup boolean := false;
begin
  c := private.tp_check(p_civil, p_phone);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['teacher_id','status','limited']);
  end if;
  if not coalesce((c ->> 'limited')::boolean, false) then
    select exists(select 1 from public.teacher_records t
      where t.id = (c ->> 'teacher_id')::uuid and t.active and t.is_senior_teacher and t.home_school_id is not null)
      into v_sup;
  end if;
  return jsonb_build_object('ok', true, 'is_sup', v_sup, 'limited', coalesce((c ->> 'limited')::boolean, false));
end $f$;
revoke all on function public.teacher_portal_login(text,text) from public;
grant execute on function public.teacher_portal_login(text,text) to anon, authenticated;
