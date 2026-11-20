-- استرجاع v420: إعادة teacher_portal_sup_school كما كانت قبل إضافة حقل الإجازة (يُشغَّل من SQL Editor)
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
do $$ declare d text; begin
 select def into d from private.v420_backup_functions where name='teacher_portal_sup_school';
 if d is null then raise exception 'لا توجد نسخة احتياطية'; end if;
 execute d;
end $$;
-- المتوقع: Success. No rows returned
