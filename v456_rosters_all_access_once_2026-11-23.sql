-- v456: private.school_teacher_rosters_all تحسب المدارس المسموحة مرة واحدة بدل can_access_school لكل مدرسة (نفس المخرَج، أسرع)
do $$ declare v text; pat text:='where private.can_access_school(s.id)'; begin
 select pg_get_functiondef(p.oid) into v from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_rosters_all';
 if (length(v)-length(replace(v,pat,'')))/length(pat)<>1 then raise exception 'v456: النص المطلوب غير موجود مرة واحدة بالضبط'; end if;
 execute replace(v,pat,'where s.id in (select unnest(private.accessible_school_ids()))');
end $$;
