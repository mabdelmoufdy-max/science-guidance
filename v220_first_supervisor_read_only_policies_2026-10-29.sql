-- v220 (2026-10-29): الموجه الأول عرض وتقارير فقط — إزالة first_supervisor من سياسات الكتابة (INSERT/UPDATE/DELETE) فقط.
-- القراءة (SELECT) والدوال RPC لم تُمس في هذا الملف. النسخة الأصلية محفوظة في private.v220_policy_backup (44 سياسة) — لا تُحذف.
do $$
declare r record; q text; w text;
begin
 for r in select * from private.v220_policy_backup loop
  q := replace(r.qual, '''admin''::app_role, ''first_supervisor''::app_role', '''admin''::app_role');
  w := replace(r.with_check, '''admin''::app_role, ''first_supervisor''::app_role', '''admin''::app_role');
  execute format('alter policy %I on %I.%I %s %s', r.policyname, r.schemaname, r.tablename,
    case when q is not null then 'using ('||q||')' else '' end,
    case when w is not null then 'with check ('||w||')' else '' end);
 end loop;
end $$;
