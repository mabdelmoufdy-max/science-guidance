-- يُشغَّل بعد نشر بوابة المعلمين الجديدة (التي ترسل المادة): يعيد التشديد (مادة مطلوبة لكل فصل متعدد المواد)
-- (v215b المطبّقة جعلت البوابة القديمة تعمل مؤقتًا: غياب المادة = قبول بلا اختيار)
do $m$
declare d text;
begin
  d := pg_get_functiondef('private.tp_subject_gate(uuid,uuid,uuid,text,uuid)'::regprocedure);
  d := replace(d, $q$if p_subject is null then return 'ok'; end if; -- مؤقت: البوابة القديمة لا ترسل المادة؛ يُعاد التشديد بعد نشر البوابة الجديدة$q$,
                  $q$if p_subject is null then return 'subject_required'; end if;$q$);
  execute d;
end $m$;
