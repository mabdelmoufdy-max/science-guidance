-- استرجاع v456: إعادة فحص can_access_school لكل مدرسة في private.school_teacher_rosters_all
do $$ declare v text; pat text:='where s.id in (select unnest(private.accessible_school_ids()))'; begin
 select pg_get_functiondef(p.oid) into v from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_rosters_all';
 if (length(v)-length(replace(v,pat,'')))/length(pat)<>1 then raise exception 'rollback v456: النص غير موجود مرة واحدة بالضبط'; end if;
 execute replace(v,pat,'where private.can_access_school(s.id)');
end $$;
