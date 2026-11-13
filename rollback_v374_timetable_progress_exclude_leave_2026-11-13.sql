-- استرجاع v374: إعادة timetable_progress كما كانت قبل استبعاد الإجازة (من النسخة المحفوظة)
do $$ begin execute (select def from private.v374_backup_functions where name='public.timetable_progress(uuid)'); end $$;
