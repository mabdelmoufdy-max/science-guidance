-- استرجاع v348: يعيد صلاحيات anon/authenticated وحالة RLS لجداول النسخ الاحتياطية الـ53 كما كانت قبل 2026-11-12
-- يعتمد على private.v348_backup_bak_acl (لا يُحذف).
-- تنبيه: الاسترجاع يعيد كشف بيانات المعلمين الشخصية للزائر بلا دخول.
do $$
declare r record; g record;
begin
  for r in select * from private.v348_backup_bak_acl loop
    for g in
      select a.privilege_type, case a.grantee when 'anon'::regrole::oid then 'anon' else 'authenticated' end grantee
      from aclexplode(r.relacl) a
      where a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)
    loop
      execute format('grant %s on public.%I to %I', g.privilege_type, r.relname, g.grantee);
    end loop;
    if not r.relrowsecurity then
      execute format('alter table public.%I disable row level security', r.relname);
    end if;
  end loop;
end $$;
-- المتوقع عند النجاح: DO، ويعود الزائر يقرأ مثلًا 324 صفًا من teacher_records_bak_20261015_form4.
