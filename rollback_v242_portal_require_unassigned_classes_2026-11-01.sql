-- استرجاع v242: إعادة الدوال الثلاث إلى نصها قبل v242 (يُسمح مجددًا بالإرسال بلا فصول بعد تأكيد، ومشرف المدرسة يختار فصلًا مسندًا)
do $r$
declare r record;
begin
  for r in select fn, def from private.v242_backup loop
    execute r.def;
  end loop;
end $r$;
