-- v448 — Record verified portal identities on newly inserted audit rows.
do $v448$
declare
  patch record;
  original_definition text;
  patched_definition text;
begin
  create table private.v448_backup_functions (
    signature text primary key,
    original_definition text not null,
    patched_definition text not null
  );
  alter table private.v448_backup_functions enable row level security;
  revoke all on private.v448_backup_functions from public, anon, authenticated;

  for patch in
    select * from (values
      ('private.tp_check(text,text)',
       $old$  return jsonb_build_object('status','ok','teacher_id', t.id,'limited', false);$old$,
       $new$  perform pg_catalog.set_config('app.portal_actor_teacher', t.id::text, true);
  perform pg_catalog.set_config('app.portal_actor_kind', 'teacher', true);
  return jsonb_build_object('status','ok','teacher_id', t.id,'limited', false);$new$),
      ('private.tp_sup_view_check(text,text,text)',
       $old$                                                                                                                  return jsonb_build_object('status','ok','school_id', v_school, 'teacher_id', v_tid, 'name', v_name, 'kind', v_kind);$old$,
       $new$                                                                                                                  perform pg_catalog.set_config('app.portal_actor_teacher', v_tid::text, true);
                                                                                                                  perform pg_catalog.set_config('app.portal_actor_kind', v_kind, true);
                                                                                                                  return jsonb_build_object('status','ok','school_id', v_school, 'teacher_id', v_tid, 'name', v_name, 'kind', v_kind);$new$),
      ('public.admin_audit_search(timestamp with time zone,timestamp with time zone,uuid,text,integer)',
       $old$a.actor_profile_id, pr.full_name, a.actor_role::text$old$,
       $new$a.actor_profile_id,
         case when a.actor_profile_id is null then nullif(a.new_data->>'portal_actor_name', '') || ' (من البوابة)' else pr.full_name end,
         a.actor_role::text$new$),
      ('public.admin_audit_search2(timestamp with time zone,timestamp with time zone,uuid,text,text,uuid,bigint,integer)',
       $old$a.actor_profile_id, pa.full_name, a.actor_role::text$old$,
       $new$a.actor_profile_id,
         case when a.actor_profile_id is null then nullif(a.new_data->>'portal_actor_name', '') || ' (من البوابة)' else pa.full_name end,
         a.actor_role::text$new$)
    ) as changes(signature, old_text, new_text)
  loop
    original_definition := pg_catalog.pg_get_functiondef(patch.signature::regprocedure);
    patched_definition := replace(original_definition, patch.old_text, patch.new_text);
    if length(original_definition) - length(replace(original_definition, patch.old_text, '')) <> length(patch.old_text) then
      raise exception 'v448: expected exactly one match in %', patch.signature;
    end if;
    execute patched_definition;
    insert into private.v448_backup_functions
    values (patch.signature, original_definition, pg_catalog.pg_get_functiondef(patch.signature::regprocedure));
  end loop;

  create function private.v448_portal_actor()
  returns trigger
  language plpgsql
  security definer
  set search_path = pg_catalog, pg_temp
  as $actor$
  declare
    teacher_id_text text := nullif(current_setting('app.portal_actor_teacher', true), '');
    actor_kind text := current_setting('app.portal_actor_kind', true);
    actor_name public.teacher_records.full_name%type;
  begin
    if new.actor_profile_id is not null
       or teacher_id_text is null
       or actor_kind is null
       or actor_kind not in ('teacher', 'sup', 'officer', 'solo')
       or teacher_id_text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      return new;
    end if;

    select t.full_name into actor_name
    from public.teacher_records t
    where t.id = teacher_id_text::uuid;
    if not found then
      return new;
    end if;

    new.new_data := coalesce(nullif(new.new_data, 'null'::jsonb), '{}'::jsonb)
      || jsonb_build_object(
        'portal_actor_teacher_id', teacher_id_text,
        'portal_actor_name', actor_name,
        'portal_actor_kind', actor_kind
      );
    return new;
  end;
  $actor$;

  revoke all on function private.v448_portal_actor() from public, anon, authenticated;
  create trigger v448_portal_actor
    before insert on public.audit_log
    for each row execute function private.v448_portal_actor();
end;
$v448$;
