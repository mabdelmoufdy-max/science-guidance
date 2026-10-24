-- Rollback v180: إعادة فتح بوابة المعلمين للمرحلة الإعدادية (إزالة الشرطين من teacher_portal_submit و teacher_portal_sup_submit)
do $$
declare d text;
begin
  d := pg_get_functiondef('public.teacher_portal_submit(text,text,text,jsonb)'::regprocedure);
  d := regexp_replace(d, E'\\n  -- v180: [^\\n]*\\n  if exists \\(select 1 from public\\.teacher_records tp[^\\n]*\\n[^\\n]*\\n    return jsonb_build_object\\(''ok'', false, ''reason'', ''closed''\\);\\n  end if;', '');
  execute d;
  d := pg_get_functiondef('public.teacher_portal_sup_submit(text,text,text,uuid,uuid,jsonb,text)'::regprocedure);
  d := replace(d, E'\n  if sch.stage = ''إعدادي'' then return jsonb_build_object(''ok'', false, ''reason'', ''closed''); end if; -- v180', '');
  execute d;
end $$;
