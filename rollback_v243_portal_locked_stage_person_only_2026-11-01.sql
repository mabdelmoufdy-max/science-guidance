-- استرجاع v243: إعادة دالتي العرض والإرسال إلى نصهما قبل v243 (الإعدادي والثانوي للعرض فقط بالكامل كما في v240، مع قيود v242)
do $r$
declare r record;
begin
  for r in select fn, def from private.v243_backup loop
    execute r.def;
  end loop;
end $r$;
