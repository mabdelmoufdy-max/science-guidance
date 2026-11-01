-- استرجاع v244: إعادة tp_pkeys وtp_apply_core وteacher_portal_submit إلى نصها قبل v244 (البوابة لا تقبل كود المعلم)
do $r$
declare r record;
begin
  for r in select fn, def from private.v244_backup loop
    execute r.def;
  end loop;
end $r$;
