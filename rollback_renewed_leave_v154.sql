-- استرجاع v154 (2026-10-21)
-- (1) إعادة الإجازات الـ13 التي جُدِّدت مؤقتًا إلى «بانتظار التجديد»
update public.teacher_long_leaves
set renewal_status='pending_renewal', decision_number=null, decision_date=null, approved_at=null,
    effective_from=null, effective_to=null,
    notes=nullif(replace(notes,'تجديد مؤقت بطلب الموجّه (2026-10-21) حتى ورود جدول/قرار رسمي. ',''),'')
where id in ('c83150a4-43fd-4b22-887f-4dc51f0d471d','95077a17-eff0-4b8e-aa8a-9e1f1fcc1b57','fccf2504-105a-4587-baec-255a68097aa0',
 'a61f0143-2645-4703-848e-e5d06979d556','c5cd552c-1a1e-4fe5-875e-99907b265ebe','4f2fc954-c38a-44c1-a4dc-34b29038f6c2',
 '791a1142-195e-4c92-9c78-3d3a11dbb619','1d8a1d95-bbe4-4680-91d4-3e7c21ac78f7','899ddf74-0adb-49f7-9739-c4b537c67d42',
 '0452bea5-590b-4130-8678-07b90a0f2105','0012ffcb-cc46-4a91-98f3-44586393d30b','45e1e5c7-f75b-4fee-a7f2-050ad716ea28',
 '521cd2c1-db51-4a21-a24d-387c7f8d4f0f');

-- (2) إزالة أسطر v154 من private.school_teacher_roster (تبقى الدالة كما قبل v153؛ لاستبعاد المجددة من الكشف مثل v153 أعد تطبيق migration v153)
do $m$
declare d text; k text;
  l1 text := E'      and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active where l.teacher_id=tr.id and l.renewal_status=''renewed'')  -- v154: الإجازة المجددة لا تتولى الإشراف\n';
  l2 text := E'        when w.on_renewed_leave then 0  -- v154\n';
  l3 text := E'        when on_renewed_leave then ''إجازة''  -- v154\n';
begin
  d := pg_get_functiondef('private.school_teacher_roster'::regproc);
  foreach k in array array[l1,l2,l3] loop
    if position(k in d)=0 then raise exception 'v154 line not found: %', k; end if;
    d := replace(d, k, '');
  end loop;
  execute d;
end $m$;
