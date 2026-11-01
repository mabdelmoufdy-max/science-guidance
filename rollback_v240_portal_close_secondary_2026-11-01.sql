-- استرجاع v240: إعادة الدوال الست إلى نصها قبل v240 (الثانوي مفتوح في البوابة مرة أخرى، الإعدادي يبقى مغلقًا كما في v180/v181)
do $r$
declare r record;
begin
  for r in select fn, def from private.v240_backup loop
    execute r.def;
  end loop;
end $r$;
