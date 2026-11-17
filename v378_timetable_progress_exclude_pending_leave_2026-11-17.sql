-- v378: «إنجاز الجداول» (timetable_progress) تستبعد أيضًا من إجازته «بانتظار التجديد» وتاريخ اليوم داخل مدة الإجازة (كانت v374 تستبعد «المجددة» فقط).
-- النسخة السابقة من الدالة في private.v378_backup_functions (لا تُحذف). الاستبدال النصي مرة واحدة بالضبط.
create table if not exists private.v378_backup_functions as
  select p.oid::regprocedure::text as sig, pg_get_functiondef(p.oid) as def
    from pg_proc p where p.oid = 'public.timetable_progress(uuid)'::regprocedure;
do $do$
declare d text; a text; b text;
begin
  d := pg_get_functiondef('public.timetable_progress(uuid)'::regprocedure);
  a := $$where l.teacher_id=t.id and l.renewal_status='renewed');$$;
  b := $$where l.teacher_id=t.id and (l.renewal_status='renewed' or (l.renewal_status='pending_renewal' and current_date between l.effective_from and coalesce(l.effective_to, current_date))));$$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'v378: النص لا يطابق مرة واحدة'; end if;
  execute replace(d, a, b);
end $do$;
