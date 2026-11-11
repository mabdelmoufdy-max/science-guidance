-- استرجاع v340: إعادة timetable_progress إلى نصها السابق (المعلم في مدرسته الأصلية فقط)
-- يعتمد على private.v340_backup_functions (لا تحذفه). شغّله في:
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
do $$
declare d text;
begin
  select def into d from private.v340_backup_functions where fn='public.timetable_progress(uuid)';
  if d is null then raise exception 'النسخة الاحتياطية غير موجودة'; end if;
  execute d;
end $$;
-- المتوقع: Success. No rows returned
