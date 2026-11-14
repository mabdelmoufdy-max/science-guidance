-- v377 (2026-11-14): حذف 6 حسابات دخول معطلة (لم تدخل قط، بلا أي عمل مسجّل) ما زالت أدوارها نشطة.
-- تبقى سجلات المعلمين نفسها (يُفك ربطها بالحساب فقط). كل أمر آمن عند التوقف في أي نقطة. شغّله أمرًا أمرًا بالترتيب.

-- 1) نسخة احتياطية (تُستعمل في الاسترجاع — لا تُحذف)
create table if not exists private.v377_backup_accounts (kind text, key text, data jsonb);
insert into private.v377_backup_accounts
select 'auth_user', u.id::text, to_jsonb(u) from auth.users u where u.id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d')
union all select 'identity', i.id::text, to_jsonb(i) from auth.identities i where i.user_id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d')
union all select 'profile', p.id::text, to_jsonb(p) from public.profiles p where p.id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d')
union all select 'user_role', r.profile_id::text||'|'||r.role::text, to_jsonb(r) from public.user_roles r where r.profile_id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d')
union all select 'teacher_link', t.id::text, jsonb_build_object('teacher_id',t.id,'profile_id',t.profile_id) from public.teacher_records t where t.profile_id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d');

-- 2) فك ربط سجل المعلم بالحساب (السجل نفسه يبقى)
update public.teacher_records set profile_id=null where profile_id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d');

-- 3) حذف الحسابات (يحذف معها الأدوار وصف profiles والهويات تلقائيًا)
delete from auth.users where id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d');

-- 4) تحقق: المتوقع 6 / 0 / 0 / 0 / 6
select (select count(*) from private.v377_backup_accounts where kind='auth_user') backed_up_users,
       (select count(*) from auth.users where id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d')) users_left,
       (select count(*) from public.profiles where id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d')) profiles_left,
       (select count(*) from public.user_roles where profile_id in ('ecae555e-a2b9-42ea-9be5-e139acf6573c','3003bf20-5ee3-498b-96a6-bfc5154f64e8','dc4eb4c8-1d4f-4808-926c-c8cfe8c5c9d5','4450eeef-0a60-4e81-9193-9d9b3eac2705','dbc4bc11-f5e6-4db7-a557-ab22970951f9','f22e320e-9f73-48a1-8d93-8d8a7307549d')) roles_left,
       (select count(*) from public.teacher_records where id in (select key::uuid from private.v377_backup_accounts where kind='teacher_link')) teachers_kept;
