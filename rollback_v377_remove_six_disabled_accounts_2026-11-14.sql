-- استرجاع v377: يعيد الحسابات الستة وأدوارها وربط سجلات المعلمين من private.v377_backup_accounts
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name),',' order by ordinal_position) into cols from information_schema.columns where table_schema='auth' and table_name='users' and is_generated='NEVER';
  execute format('insert into auth.users (%1$s) select %1$s from jsonb_populate_record(null::auth.users, null) where false', cols);
  execute format('insert into auth.users (%1$s) select %1$s from private.v377_backup_accounts b, lateral jsonb_populate_record(null::auth.users, b.data) where b.kind=''auth_user'' on conflict (id) do nothing', cols);
  select string_agg(quote_ident(column_name),',' order by ordinal_position) into cols from information_schema.columns where table_schema='auth' and table_name='identities' and is_generated='NEVER';
  execute format('insert into auth.identities (%1$s) select %1$s from private.v377_backup_accounts b, lateral jsonb_populate_record(null::auth.identities, b.data) where b.kind=''identity'' on conflict do nothing', cols);
end $$;
insert into public.profiles select (jsonb_populate_record(null::public.profiles, data)).* from private.v377_backup_accounts where kind='profile' on conflict (id) do nothing;
insert into public.user_roles select (jsonb_populate_record(null::public.user_roles, data)).* from private.v377_backup_accounts where kind='user_role' on conflict do nothing;
update public.teacher_records t set profile_id=(b.data->>'profile_id')::uuid from private.v377_backup_accounts b where b.kind='teacher_link' and t.id=(b.data->>'teacher_id')::uuid;
