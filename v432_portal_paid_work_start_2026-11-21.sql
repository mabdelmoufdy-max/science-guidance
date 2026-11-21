-- v432: معلم الأجر يعدّل «تاريخ استلام العمل» من بوابة المعلمين (له هو فقط).
alter table public.teacher_portal_settings add column if not exists paid_ws_edit_open boolean not null default true;

create or replace function public.teacher_portal_paid_ws_set(p_civil text, p_phone text, p_date date)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $f$
declare c jsonb; t public.teacher_records; v_open boolean;
begin
  c := private.tp_check(p_civil, p_phone);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['teacher_id','status','limited']);
  end if;
  if coalesce((c ->> 'limited')::boolean, false) then return jsonb_build_object('ok', false, 'reason', 'no_phone'); end if;
  select coalesce(paid_ws_edit_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not coalesce(v_open, true) then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  select * into t from public.teacher_records where id = (c ->> 'teacher_id')::uuid for update;
  if t.work_type is distinct from 'paid' then return jsonb_build_object('ok', false, 'reason', 'not_paid'); end if;
  if p_date is null or p_date < date '1970-01-01' or p_date > current_date then
    return jsonb_build_object('ok', false, 'reason', 'invalid', 'field', 'work_start_date');
  end if;
  if t.work_start_date is not distinct from p_date then return jsonb_build_object('ok', false, 'reason', 'no_change'); end if;
  update public.teacher_records set work_start_date = p_date where id = t.id;
  insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
    values ('teacher', 'teacher_portal_paid_ws_set', 'teacher', t.id::text,
            jsonb_build_object('work_start_date', t.work_start_date), jsonb_build_object('work_start_date', p_date));
  return jsonb_build_object('ok', true, 'work_start_date', p_date);
end $f$;
revoke all on function public.teacher_portal_paid_ws_set(text,text,date) from public;
grant execute on function public.teacher_portal_paid_ws_set(text,text,date) to anon, authenticated;
