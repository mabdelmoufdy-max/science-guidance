-- استرجاع تصحيح الرقم القومي للموجه كمال سعد محمد حمدان (2026-11-08): 26801062800357 ← 26801062800257
-- رابط التشغيل: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يعتمد على private.backup_kamal_civil_2026_11_08 (لا يُحذف).
-- عند النجاح: الدخول يعود بالرقم القديم 26801062800257 بنفس كلمة المرور، وجدول المرجع لم يُغيَّر أصلًا.
do $r$
declare b record;
begin
  select * into b from private.backup_kamal_civil_2026_11_08 limit 1;
  alter table public.profiles disable trigger trg_profile_civil_id_immutable;
  alter table public.supervisors disable trigger trg_supervisor_civil_id_immutable;
  update public.profiles set civil_id=b.old_civil where id=b.user_id and civil_id=b.new_civil;
  update public.supervisors set civil_id=b.old_civil where id=b.supervisor_id and civil_id=b.new_civil;
  alter table public.profiles enable trigger trg_profile_civil_id_immutable;
  alter table public.supervisors enable trigger trg_supervisor_civil_id_immutable;
  update auth.users set email=b.old_email, updated_at=now() where id=b.user_id;
  update auth.identities set identity_data=b.old_identity, updated_at=now() where user_id=b.user_id and provider='email';
end
$r$;
