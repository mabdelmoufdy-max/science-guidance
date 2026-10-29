-- v220b (2026-10-29): إزالة first_supervisor من 9 دوال كتابة + بند إنشاء الحسابات (النسخ الأصلية في private.v220_function_backup — لا تُحذف).
do $$
declare r record; d text;
begin
 for r in select * from private.v220_function_backup loop
  if r.proname='service_link_created_system_user_atomic' then
    d := regexp_replace(r.def, E'\\s*or \\(p_actor_role=''first_supervisor'' and p_role in \\(''stage_coordinator'',''supervisor''\\)\\)', '', 'g');
  else
    d := regexp_replace(r.def, E'''first_supervisor''(::public\\.app_role)?\\s*,\\s*', '', 'g');
    d := regexp_replace(d, E'\\s*,\\s*''first_supervisor''(::public\\.app_role)?\\s*\\)', ')', 'g');
  end if;
  execute d;
 end loop;
end $$;
