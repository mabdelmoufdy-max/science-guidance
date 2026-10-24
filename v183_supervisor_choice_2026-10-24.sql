-- v183 (2026-10-24، بطلب المستخدم «نفذ ما ارسلته لك واجعل القاعدة الاقدم او اختيار الموجه»)
-- مشرف المادة = اختيار الموجه للمدرسة إن وُجد (school_supervisor_choice؛ teacher_id فارغ = لا مشرف)، وإلا الأقدم كما كان.
-- طُبِّق 2026-10-24 (بعد إصلاح خطأ one_active_senior_teacher_per_school: المنتدبة جزئيًا المختارة لا تُرفع علامتها). لا تُشغّله مرة ثانية. الاسترجاع: rollback_v183_supervisor_choice_2026-10-24.sql
begin;

create table public.school_supervisor_choice(
  school_id uuid primary key references public.schools(id),
  teacher_id uuid references public.teacher_records(id),
  note text,
  chosen_at timestamptz not null default now(),
  chosen_by uuid default auth.uid()
);
alter table public.school_supervisor_choice enable row level security;
create policy ssc_read on public.school_supervisor_choice for select to authenticated using (true);
grant select on public.school_supervisor_choice to authenticated;

do $mig$
declare d text; o text;
begin
  -- 1) private.school_teacher_roster
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_roster';
  o := d;
  d := replace(d, E'  ), scope_supervisor as (\n    select tr.id as teacher_id\n    from public.teacher_records tr\n    join roster_ids ri on ri.id=tr.id\n    where tr.active',
    E'  ), supervisor_choice as (\n    select c.teacher_id from public.school_supervisor_choice c where c.school_id=p_school_id  -- v183\n  ), scope_supervisor as (\n    select tr.id as teacher_id\n    from public.teacher_records tr\n    join roster_ids ri on ri.id=tr.id\n    join supervisor_choice sc0 on sc0.teacher_id=tr.id\n    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active where l.teacher_id=tr.id and l.renewal_status=''renewed'')\n    union all\n    (select tr.id as teacher_id\n    from public.teacher_records tr\n    join roster_ids ri on ri.id=tr.id\n    where not exists (select 1 from supervisor_choice)\n      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p_school_id)\n      and tr.active');
  if d=o then raise exception 'roster: scope_supervisor not replaced'; end if; o := d;
  d := replace(d, E'    limit 1\n  ), scope_teaching as (', E'    limit 1)\n  ), scope_teaching as (');
  if d=o then raise exception 'roster: limit not replaced'; end if; o := d;
  d := replace(d, E'        when ss.teacher_id=w.teacher_id then 2\n        else 0\n      end::integer as global_supervision_periods',
    E'        when ss.teacher_id=w.teacher_id then 2\n        when exists (select 1 from public.school_supervisor_choice c2 where c2.teacher_id=w.teacher_id and c2.school_id<>p_school_id) then 2  -- v183\n        else 0\n      end::integer as global_supervision_periods');
  if d=o then raise exception 'roster: global not replaced'; end if; o := d;
  d := replace(d, E'          then case when coalesce(w.is_senior_teacher,false) then 2 else 0 end',
    E'          then case when coalesce(w.supervision_periods,0)>0 then 2 else 0 end  -- v183');
  if d=o then raise exception 'roster: partial-in not replaced'; end if;
  execute d;

  -- 2) private.school_teacher_rosters_all
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='school_teacher_rosters_all';
  o := d;
  d := replace(d, E'    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.delegations d where d.teacher_id=tr.id and d.to_school_id=p.sid',
    E'    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id=tr.id and c1.school_id<>p.sid)  -- v183\n      and not exists (select 1 from public.delegations d where d.teacher_id=tr.id and d.to_school_id=p.sid');
  if d=o then raise exception 'all: ranked not replaced'; end if; o := d;
  d := replace(d, E'  ), ss as (\n    select r.sid, r.tid from ranked r where r.rn=1\n  ),',
    E'  ), ss as (\n    select r.sid, r.tid from ranked r where r.rn=1 and not exists (select 1 from public.school_supervisor_choice c where c.school_id=r.sid)\n    union all  -- v183: اختيار الموجه\n    select p.sid, p.tid from pairs p\n    join public.school_supervisor_choice c on c.school_id=p.sid and c.teacher_id=p.tid\n    join public.teacher_records tr on tr.id=p.tid\n    where tr.active and tr.work_type=''permanent''::public.work_type\n      and not exists (select 1 from public.teacher_long_leaves l join public.academic_years ay on ay.id=l.academic_year_id and ay.is_active where l.teacher_id=tr.id and l.renewal_status=''renewed'')\n  ),');
  if d=o then raise exception 'all: ss not replaced'; end if; o := d;
  d := replace(d, E'        when ss.tid=w.teacher_id then 2\n        else 0\n      end::integer as global_supervision_periods,',
    E'        when ss.tid=w.teacher_id then 2\n        when exists (select 1 from public.school_supervisor_choice c2 where c2.teacher_id=w.teacher_id and c2.school_id<>p.sid) then 2  -- v183\n        else 0\n      end::integer as global_supervision_periods,');
  if d=o then raise exception 'all: global not replaced'; end if; o := d;
  d := replace(d, E'          then case when coalesce(w.is_senior_teacher,false) then 2 else 0 end',
    E'          then case when coalesce(w.supervision_periods,0)>0 then 2 else 0 end  -- v183');
  if d=o then raise exception 'all: partial-in not replaced'; end if;
  execute d;

  -- 3) private.sync_school_senior_teacher
  d := pg_get_functiondef('private.sync_school_senior_teacher'::regproc);
  o := d;
  d := replace(d, E'  where not exists (select 1 from public.supervision_declined sd where sd.teacher_id = tr.id and sd.school_id = p_school_id)',
    E'  where not exists (select 1 from public.supervision_declined sd where sd.teacher_id = tr.id and sd.school_id = p_school_id)\n    and not exists (select 1 from public.school_supervisor_choice c1 where c1.teacher_id = tr.id and c1.school_id <> p_school_id)  -- v183');
  if d=o then raise exception 'sync: winner filter not replaced'; end if; o := d;
  d := replace(d, E'  limit 1;\n\n  update public.teacher_records tr\n  set is_senior_teacher = false,',
    E'  limit 1;\n\n  -- v183: اختيار الموجه يتقدم على الأقدمية (teacher_id فارغ = لا مشرف)\n  if exists (select 1 from public.school_supervisor_choice c where c.school_id = p_school_id) then\n    select c.teacher_id into v_winner from public.school_supervisor_choice c where c.school_id = p_school_id;\n  end if;\n\n  update public.teacher_records tr\n  set is_senior_teacher = false,');
  if d=o then raise exception 'sync: choice not inserted'; end if; o := d;
  d := replace(d, E'    and tr.id is distinct from v_winner\n',
    E'    and tr.id is distinct from v_winner\n    and not exists (select 1 from public.school_supervisor_choice c3 where c3.teacher_id = tr.id and c3.school_id <> p_school_id)  -- v183\n');
  if d=o then raise exception 'sync: reset guard not replaced'; end if; o := d;
  d := replace(d, E'    where tr.id = v_winner\n      and tr.is_senior_teacher is distinct from true;',
    E'    where tr.id = v_winner\n      and tr.is_senior_teacher is distinct from true\n      and (tr.home_school_id = p_school_id or exists (select 1 from public.delegations d where d.teacher_id = tr.id and d.to_school_id = p_school_id and d.delegation_type = ''full''::public.delegation_type and d.active and d.start_date <= current_date and (d.end_date is null or d.end_date >= current_date)));  -- v183: المنتدب جزئيًا المختار لا تُرفع علامته (قيد مشرف واحد لكل مدرسة أصلية)؛ إشرافه من school_supervisor_choice');
  if d=o then raise exception 'sync: winner flag guard not replaced'; end if;
  execute d;

  -- 4) public.teacher_workload_summary: الإشراف = العلامة أو اختيار الموجه في أي مدرسة
  d := pg_get_viewdef('public.teacher_workload_summary'::regclass);
  o := d;
  d := replace(d, E'WHEN (tr.is_senior_teacher AND (tr.work_type = ''permanent''::work_type)) THEN 2',
    E'WHEN ((tr.is_senior_teacher OR (EXISTS ( SELECT 1 FROM public.school_supervisor_choice c WHERE (c.teacher_id = tr.id)))) AND (tr.work_type = ''permanent''::work_type)) THEN 2');
  if d=o then raise exception 'view: supervision not replaced'; end if;
  execute 'create or replace view public.teacher_workload_summary as ' || d;
end
$mig$;

-- البيانات: اختيار الموجهين (قائمة 2026-10-24)
insert into public.school_supervisor_choice(school_id,teacher_id,note) values
-- عبد الناصر سعيد
('f3595d10-4d50-4a2c-b1c4-99ac7cb40a85','2870e86e-2012-4e45-b9b0-8ce12f2e5a74','قائمة الموجهين 2026-10-24'), -- جراجوس ع بنات / هبة عباس
('b7880e77-176b-45b8-b66c-19eefef7070c','e807af6d-6315-4ac6-b848-5857304728fa','قائمة الموجهين 2026-10-24'), -- العصارة / ابتسام عبيد
('607ed619-9119-4da1-be1e-1c4d9501ffb7','65bf3a29-1d09-46d6-ae64-f63070b98b95','قائمة الموجهين 2026-10-24'), -- الجمالية اعدادي / فاطمة القاسم (منتدبة جزئيًا)
('d834a5e3-cf67-44ab-a900-e5de4ca13c68','d3c71a99-cebb-4ff3-b42d-373c74352f7c','قائمة الموجهين 2026-10-24'), -- المفرجية / احلام
('cb1cde21-0591-4245-971a-71335b840276',null,'قائمة الموجهين 2026-10-24: لا يوجد إشراف'), -- البخاينة
-- شيماء محمد
('480c84d4-ceff-4996-9888-6855cdd20e64','aa7b9b9e-cf2c-4489-baf0-4220ac8a4758','قائمة الموجهين 2026-10-24'), -- ابن دقيق العيد / صفاء عربي
('e3c64100-4294-4b79-b5a0-839174231250','0e427618-7b11-4dd2-95ee-677aea3e8b27','قائمة الموجهين 2026-10-24'), -- قوص ع بنين / عزة النوبي
('385a3919-63e4-49fc-bb30-effb8a74388d','ff4217a4-541d-4f8b-b233-ed500a360d32','قائمة الموجهين 2026-10-24'), -- البهاء زهير / محمد ابوبكر
('787d8b12-5e4e-4d3b-a6c8-c1a453a14257','193b43b1-2a29-4de9-9138-da4886ad1c42','قائمة الموجهين 2026-10-24'), -- عبدالعزيز القوصي / منال
('a33d9d52-4dd9-4579-86e5-248f5c92d76e','7fbf6a6b-5608-49a4-a746-a7d43a53050d','قائمة الموجهين 2026-10-24'), -- مصنع السكر / مدحت مهني
('2f4eb287-653c-45dd-b79e-066b418d29e5','b004887b-5101-41b9-af5a-05d17317ef3d','قائمة الموجهين 2026-10-24'), -- شهيد مصطفى حراجية / اميره جبريل
('a427709e-4f09-40be-aebc-a8fb2f93a01c','6dc2c5c2-644c-4533-a761-4a171f7a0371','قائمة الموجهين 2026-10-24'), -- الحلة / فاطمه حسن
('071c805a-6f46-4e29-9e1a-011fb4103239','57b95748-23cd-46b0-a600-d6208742fdec','قائمة الموجهين 2026-10-24'), -- النصر بنات مهني / فاطمة بهى الدين
('fc392803-3675-4aa9-a351-0a6103a3eda3','2f5acae1-9012-4358-af06-352cb9c1464b','قائمة الموجهين 2026-10-24'), -- السادات / بسمه عبادي
-- كمال
('a6a1a2fc-e3b5-4334-b854-8171260b2c8e','c836634f-805b-47bd-9a0d-98d5eab63bf8','قائمة الموجهين 2026-10-24'), -- الشهيد مجدي / نعمة سعيد
('88343212-19ff-4e35-b0a5-0eec46fd8425','efa4fd4b-23bf-496a-bdce-f7124ac3d623','قائمة الموجهين 2026-10-24'), -- الكراتية / ناهد احمد عوض
('0033a138-3d23-4458-a1a6-991a87a80da2','27f0a1c0-e750-4737-a598-075b9b22e147','قائمة الموجهين 2026-10-24'), -- حاجر خزام / سهير
('db948157-15dc-486b-94e3-b6193faacff5','caa4deb2-91f3-4817-88ee-024d53909361','قائمة الموجهين 2026-10-24'), -- قوص المهني / اميمة النجار
('764c64c1-2d2c-4928-a80e-ca4830f42302',null,'قائمة الموجهين 2026-10-24: لا يوجد مشرف'), -- المخزن
('6c32e90b-147d-49ab-a9b8-2a329ea29a63',null,'قائمة الموجهين 2026-10-24: لا يوجد مشرف'), -- المنشية
('dce1389b-fe25-4d66-9cc4-0ea330a7e438',null,'قائمة الموجهين 2026-10-24: لا يوجد مشرف'), -- المقارين
('c4f2660b-90c2-4451-b33f-d79eeef11a13',null,'قائمة الموجهين 2026-10-24: لا يوجد مشرف'), -- التحرير حراجية بنين
('f5232069-26f4-4320-995f-48ea4ad12004','df4104b7-48de-422a-9544-703f9d98cdbb','قائمة الموجهين 2026-10-24'), -- ابو بكر الصديق سندل / فاطمة عبداللاه
('ed4f660b-ff4b-4116-9fc0-689f6518183a','269f12c6-95ff-4dac-a061-b3413f26b978','قائمة الموجهين 2026-10-24'), -- المقربية / سهام خليل
('172de0a2-39d0-40da-8994-e0eef2c2b68c','790576da-65ba-475b-993d-558f58783e2e','قائمة الموجهين 2026-10-24'), -- الشهيد شحات / فاطمة عبد الهادي
('966b909d-1901-44e1-8f1d-ea6e22b952e1','a4f48f69-12e8-460e-962f-895c3f1c03ae','قائمة الموجهين 2026-10-24'), -- ابو العلا المعري / هناء
('fdf478d1-2dbb-4b6c-9d1b-b390a90ce309','3a2d579e-db96-487e-b4af-9df5304c46ac','قائمة الموجهين 2026-10-24'), -- العبور كوم سخين / كريمة عبادى
('bffb833b-311e-46b8-9b5f-3e85b1af06c2','d364c5d5-7f45-4731-ba3e-bf2f37d37db6','قائمة الموجهين 2026-10-24'), -- العليقات / هالة سعد وهب الله
('973da232-0c18-4cfd-8f82-0367db6630ab','8a6a61f2-ba33-4ea7-aa43-103ff67c5780','قائمة الموجهين 2026-10-24'), -- نجع معوض / مغربي
('3c309b3c-d9f1-4e85-8c1f-a77376ac7655','0cd0751c-0f14-4a41-8564-32e7f45a2bc2','قائمة الموجهين 2026-10-24'), -- نجع السواقي / سحر
('ed71fed5-43da-4aa1-95bc-57dac544fe74','2438ef7c-c2e4-4ddf-a48c-727865d1fd9d','قائمة الموجهين 2026-10-24'), -- خزام الجديدة / محمد احمد ادم
('ad8713d9-8352-4e1b-9fd7-9ad9662933db','a9cf0a15-39ee-404c-80ac-e9babc30f3cc','قائمة الموجهين 2026-10-24'), -- الخرانقة الجديدة / رحاب الليثي
('a328ba9e-c647-43bb-b6b7-5a0f96ad83a1',null,'قائمة الموجهين 2026-10-24: لا يوجد مشرف'), -- الخرانقة القديمة
('1ee424cd-6713-41cc-8f26-f421d01087d0','f3e919cb-6c11-4bb9-bec7-0f03147d578a','قائمة الموجهين 2026-10-24'), -- كوبري حجازة / مروة حنفي
-- محمد معله
('ca771e9c-eb7e-4396-8fef-b359ee5f0de7','f7585b99-b49f-4a94-be97-d32de5c959ba','قائمة الموجهين 2026-10-24'), -- عباسة / ايمان محمود
('2041e435-4a54-44dd-83d0-0a9bc8ade535','377dff96-ac2f-42c0-86b3-30c47ab5f800','قائمة الموجهين 2026-10-24'), -- نجع غلاب / نوره عبد الراضي (منتدبة جزئيًا)
('5851d087-0504-40dc-8347-35701925cc7e','085ca778-ad51-4bf0-8470-d30d4e3c5477','قائمة الموجهين 2026-10-24'), -- الحمر والجعافرة / محمود عبدالمفدي
('fe98af7a-ce7b-437a-ad26-a95b13c23c67','614e604b-cea2-4a55-b994-be31cd8a8b52','قائمة الموجهين 2026-10-24'), -- نجع البرج / مني جادالله (منتدبة جزئيًا)
('bb513407-d395-443b-bd9d-50a2f73fc849','0cdb54c6-9079-422a-b36a-8d9fd7861e2b','قائمة الموجهين 2026-10-24'); -- المسيد / منى حمتو

-- الموجه المسؤول عن المدرسة
update public.schools set supervisor_id='bacb6309-6181-4afb-b005-c390df6295c5' where id in ('ed4f660b-ff4b-4116-9fc0-689f6518183a','fdf478d1-2dbb-4b6c-9d1b-b390a90ce309','1ee424cd-6713-41cc-8f26-f421d01087d0'); -- المقربية، العبور، كوبري حجازة ← كمال
update public.schools set supervisor_id='4d69363b-0b47-4d94-8c2d-d0e38d8c0f0a' where id='fe98af7a-ce7b-437a-ad26-a95b13c23c67'; -- نجع البرج ← محمد معله
update public.schools set supervisor_id='54161bac-29ed-4276-a0e0-a45b23ca4b8e' where id='2f4eb287-653c-45dd-b79e-066b418d29e5'; -- شهيد مصطفى حراجية ← شيماء

-- إعادة حساب علامة مشرف المادة (لا تُرفع للمنتدبات جزئيًا؛ إشرافهن من جدول الاختيار) للمدارس المعنية والمدارس الأصلية للمنتدبات الثلاث
select private.sync_school_senior_teacher(s) from (
  select school_id s from public.school_supervisor_choice
  union select home_school_id from public.teacher_records where id in ('65bf3a29-1d09-46d6-ae64-f63070b98b95','377dff96-ac2f-42c0-86b3-30c47ab5f800','614e604b-cea2-4a55-b994-be31cd8a8b52')
) x;

commit;

-- تحقق: يجب أن تظهر 39 مدرسة
select count(*) as choices from public.school_supervisor_choice;
