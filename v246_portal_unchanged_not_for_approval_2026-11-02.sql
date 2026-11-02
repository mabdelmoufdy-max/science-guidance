-- v246 (2026-11-02، بطلب المستخدم «نفذ أ»): «بياناتي صحيحة» بلا أي تغيير لا يدخل قائمة الاعتماد:
-- يُحفظ سجلًا معتمدًا تلقائيًا (status=approved، review_note «مؤكد تلقائيًا (لا تغيير)»)،
-- ولا يُلغي (superseded) طلبًا معلقًا سابقًا للمعلم. الطلب الجديد والتعديل الحقيقي بلا تغيير.
-- الاسترجاع: rollback_v246_portal_unchanged_not_for_approval_2026-11-02.sql (يعتمد على private.v246_backup)
create table if not exists private.v246_backup(name text primary key, def text, saved_at timestamptz default now());
insert into private.v246_backup(name, def)
select 'teacher_portal_submit', pg_get_functiondef('public.teacher_portal_submit'::regproc)
on conflict (name) do nothing;

do $mig$
declare d text := pg_get_functiondef('public.teacher_portal_submit'::regproc); n text;
  a1 text := $a$  update public.teacher_portal_submissions set status = 'superseded' where civil_id = v_civil and status = 'pending';$a$;
  b1 text := $a$  if not v_unchanged then -- v246
    update public.teacher_portal_submissions set status = 'superseded' where civil_id = v_civil and status = 'pending';
  end if;$a$;
  a2 text := $a$unchanged, deleg, subject_choices)$a$;
  b2 text := $a$unchanged, deleg, subject_choices, status, reviewed_at, review_note)$a$;
  a3 text := $a$      nullif(v_choices, '{}'::jsonb));$a$;
  b3 text := $a$      nullif(v_choices, '{}'::jsonb),
      case when v_unchanged then 'approved' else 'pending' end, -- v246
      case when v_unchanged then now() end,
      case when v_unchanged then 'مؤكد تلقائيًا (لا تغيير)' end);$a$;
begin
  foreach n in array array[a1,a2,a3] loop
    if (length(d) - length(replace(d, n, ''))) / length(n) <> 1 then raise exception 'v246: النص غير موجود مرة واحدة: %', n; end if;
  end loop;
  d := replace(replace(replace(d, a1, b1), a2, b2), a3, b3);
  execute d;
end $mig$;
