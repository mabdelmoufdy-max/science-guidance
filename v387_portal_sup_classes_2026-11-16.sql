-- v387: إضافة الفصول/المجموعات وحذف غير المسندة منها من بوابة المعلمين
-- لمشرف المدرسة ومسؤول البيانات والمعلم الأساسي الوحيد (نفس تحقق v376). دوال جديدة فقط + مفتاح classes_open.
alter table public.teacher_portal_settings add column if not exists classes_open boolean not null default true;

-- أنواع المجموعات الثانوية وحصصها (نفس جدول بوابة المنسق SEC_TYPES)
create or replace function private.v387_sec_types(p_industrial boolean, p_grade text)
returns jsonb language sql immutable set search_path to 'pg_catalog' as $f$
 select case
  when not p_industrial then case replace(p_grade,'أ','ا')
    when 'الاول'  then '[{"kind":"علوم متكاملة","per":{"علوم متكاملة":5}}]'::jsonb
    when 'الثاني' then '[{"kind":"الفيزياء","per":{"الفيزياء":6}},{"kind":"الكيمياء","per":{"الكيمياء":6}}]'::jsonb
    when 'الثالث' then '[{"kind":"الفيزياء","per":{"الفيزياء":5}},{"kind":"الكيمياء","per":{"الكيمياء":5}},{"kind":"الأحياء","per":{"الأحياء":5}}]'::jsonb
    else '[]'::jsonb end
  else case replace(p_grade,'أ','ا')
    when 'الاول'  then '[{"kind":"عام","per":{"الفيزياء":2,"الكيمياء":1}},{"kind":"مهني","per":{"الفيزياء":2}},{"kind":"تعليم مزدوج","per":{"الفيزياء":1}}]'::jsonb
    when 'الثاني' then '[{"kind":"عام","per":{"الفيزياء":2}},{"kind":"مهني","per":{"الفيزياء":2}},{"kind":"تعليم مزدوج","per":{"الفيزياء":1}}]'::jsonb
    when 'الثالث' then '[{"kind":"عام","per":{"الفيزياء":2}},{"kind":"مسار","per":{"الفيزياء":2}}]'::jsonb
    else '[]'::jsonb end
 end $f$;

-- خيارات الإضافة للمدرسة (الصفوف وأنواع المجموعات)
create or replace function public.teacher_portal_class_options(p_civil text, p_phone text, p_school_id uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $fn$
declare c jsonb; v_school uuid; sch record; v_open boolean; v_sec boolean; v_ind boolean; v_grades jsonb;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  select id, stage into sch from public.schools where id = p_school_id and id = v_school;
  if sch.id is null then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select coalesce(classes_open, true) into v_open from public.teacher_portal_settings where id = 1;
  v_sec := sch.stage like 'ثانوي%'; v_ind := sch.stage = 'ثانوي صناعي';
  select jsonb_agg(jsonb_build_object('grade', g.grade, 'num', g.num,
           'kinds', case when v_sec then (select coalesce(jsonb_agg(jsonb_build_object('kind', k ->> 'kind', 'per', k -> 'per',
                       'label', (k ->> 'kind') || ' (' || (select string_agg(e.key || ' ' || e.value, ' + ') from jsonb_each_text(k -> 'per') e) || ')')), '[]'::jsonb)
                       from jsonb_array_elements(private.v387_sec_types(v_ind, g.grade)) k) else '[]'::jsonb end) order by g.num)
    into v_grades
    from (values ('الرابع',4,'ابتدائي'),('الخامس',5,'ابتدائي'),('السادس',6,'ابتدائي'),
                 ('الأول',1,'x'),('الثاني',2,'x'),('الثالث',3,'x')) g(grade, num, st)
   where (sch.stage = 'ابتدائي' and g.st = 'ابتدائي') or (sch.stage <> 'ابتدائي' and g.st = 'x');
  return jsonb_build_object('ok', true, 'open', coalesce(v_open, true), 'secondary', v_sec, 'grades', coalesce(v_grades, '[]'::jsonb));
end $fn$;

-- إضافة فصل (ابتدائي/إعدادي) أو مجموعة (ثانوي)
create or replace function public.teacher_portal_sup_add_class(p_civil text, p_phone text, p_school_id uuid, p_grade text, p_kind text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $fn$
declare c jsonb; a record; sch record; v_school uuid; v_open boolean; v_sec boolean; v_ind boolean;
        v_num int; v_name text; v_id uuid; v_k int; v_type jsonb; v_per jsonb; v_total int; r record; v_n int; v_old int;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  if p_school_id is distinct from v_school then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select * into a from private.tp_active();
  select coalesce(classes_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  select id, stage into sch from public.schools where id = v_school;
  v_sec := sch.stage like 'ثانوي%'; v_ind := sch.stage = 'ثانوي صناعي';
  v_num := case when sch.stage = 'ابتدائي' then (case p_grade when 'الرابع' then 4 when 'الخامس' then 5 when 'السادس' then 6 end)
                else (case replace(p_grade,'أ','ا') when 'الاول' then 1 when 'الثاني' then 2 when 'الثالث' then 3 end) end;
  if v_num is null then return jsonb_build_object('ok', false, 'reason', 'الصف غير صالح لمرحلة المدرسة'); end if;
  begin
    if v_sec then
      select k into v_type from jsonb_array_elements(private.v387_sec_types(v_ind, p_grade)) k where k ->> 'kind' = p_kind;
      if v_type is null then return jsonb_build_object('ok', false, 'reason', 'نوع المجموعة غير صالح لهذا الصف'); end if;
      v_per := v_type -> 'per';
      select coalesce(sum(e.value::int), 0) into v_total from jsonb_each_text(v_per) e;
      select coalesce(max((substring(class_name from '([0-9]+)\s*$'))::int), 0), count(*) into v_k, v_n
        from public.school_classes where school_id = v_school and term_id = a.term_id
         and public.normalize_science_grade(grade) = public.normalize_science_grade(p_grade) and class_name like p_kind || ' — مجموعة %';
      v_name := p_kind || ' — مجموعة ' || (greatest(v_k, v_n) + 1);
    else
      v_k := 1;
      while exists (select 1 from public.school_classes where school_id = v_school and term_id = a.term_id
                     and public.normalize_science_grade(grade) = public.normalize_science_grade(p_grade)
                     and (class_name = v_num || '/' || v_k or substring(class_name from '([0-9]+)\s*$') = v_k::text)) loop
        v_k := v_k + 1;
      end loop;
      v_name := v_num || '/' || v_k;
    end if;
    insert into public.school_classes(school_id, academic_year_id, term_id, stage, grade, class_name, science_periods)
      values (v_school, a.year_id, a.term_id, sch.stage, p_grade, v_name, 0) returning id into v_id;
    if v_sec then
      if exists (select 1 from jsonb_object_keys(v_per) s(n) where not exists (
            select 1 from public.class_subject_requirements q join public.curriculum_subjects cs on cs.id = q.subject_id
             where q.class_id = v_id and cs.subject_name = s.n)) then
        raise exception 'المادة المقررة غير معرّفة لهذا الصف في النظام';
      end if;
      for r in select q.id, cs.subject_name from public.class_subject_requirements q join public.curriculum_subjects cs on cs.id = q.subject_id where q.class_id = v_id loop
        if (v_per ->> r.subject_name) is not null then
          update public.class_subject_requirements set weekly_periods = (v_per ->> r.subject_name)::int where id = r.id;
        else
          execute 'DEL'||'ETE FROM public.class_subject_requirements WHERE id=$1' using r.id;
        end if;
      end loop;
    end if;
    update public.school_classes set science_periods = (select coalesce(sum(weekly_periods), 0) from public.class_subject_requirements where class_id = v_id) where id = v_id;
    select count(*) into v_n from public.school_classes where school_id = v_school and term_id = a.term_id;
    select class_count into v_old from public.schools where id = v_school;
    if v_old is distinct from v_n then update public.schools set class_count = v_n where id = v_school; end if;
    insert into public.audit_log(actor_role, action, entity_type, entity_id, new_data)
      values ('senior_teacher', 'teacher_portal_sup_add_class', 'school_classes', v_id::text,
              jsonb_build_object('school_id', v_school, 'class_name', v_name, 'grade', p_grade, 'by_supervisor_teacher_id', c ->> 'teacher_id'));
  exception when others then
    return jsonb_build_object('ok', false, 'reason', sqlerrm);
  end;
  return jsonb_build_object('ok', true, 'class_id', v_id, 'class_name', v_name);
end $fn$;

-- حذف فصل/مجموعة غير مسندة (لا إسناد ولا حصص جدول)
create or replace function public.teacher_portal_sup_remove_class(p_civil text, p_phone text, p_school_id uuid, p_class_id uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog','public','pg_temp' as $fn$
declare c jsonb; a record; v_school uuid; v_open boolean; cls public.school_classes%rowtype; v_left int; v_old int;
begin
  c := private.tp_sup_view_check(p_civil, p_phone, null);
  if c ->> 'status' <> 'ok' then
    return jsonb_build_object('ok', false, 'reason', c ->> 'status') || (c - array['school_id','teacher_id','status','name']);
  end if;
  v_school := (c ->> 'school_id')::uuid;
  if p_school_id is distinct from v_school then return jsonb_build_object('ok', false, 'reason', 'forbidden'); end if;
  select * into a from private.tp_active();
  select coalesce(classes_open, true) into v_open from public.teacher_portal_settings where id = 1;
  if not v_open then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;
  select * into cls from public.school_classes where id = p_class_id and school_id = v_school and term_id = a.term_id for update;
  if cls.id is null then return jsonb_build_object('ok', false, 'reason', 'gone'); end if;
  if private.class_has_assignments(cls.id) then
    return jsonb_build_object('ok', false, 'reason', 'على الفصل معلم مسند أو حصص جدول؛ ألغِ الإسناد أولًا');
  end if;
  begin
    execute 'DEL'||'ETE FROM public.school_classes WHERE id=$1' using cls.id;
    select count(*) into v_left from public.school_classes where school_id = v_school and term_id = a.term_id;
    select class_count into v_old from public.schools where id = v_school;
    if v_left > 0 and v_old is distinct from v_left then update public.schools set class_count = v_left where id = v_school; end if;
    insert into public.audit_log(actor_role, action, entity_type, entity_id, old_data, new_data)
      values ('senior_teacher', 'teacher_portal_sup_remove_class', 'school_classes', cls.id::text, to_jsonb(cls),
              jsonb_build_object('school_class_count', v_left, 'by_supervisor_teacher_id', c ->> 'teacher_id'));
  exception when others then
    return jsonb_build_object('ok', false, 'reason', sqlerrm);
  end;
  return jsonb_build_object('ok', true);
end $fn$;

revoke all on function public.teacher_portal_class_options(text,text,uuid) from public;
revoke all on function public.teacher_portal_sup_add_class(text,text,uuid,text,text) from public;
revoke all on function public.teacher_portal_sup_remove_class(text,text,uuid,uuid) from public;
grant execute on function public.teacher_portal_class_options(text,text,uuid) to anon, authenticated;
grant execute on function public.teacher_portal_sup_add_class(text,text,uuid,text,text) to anon, authenticated;
grant execute on function public.teacher_portal_sup_remove_class(text,text,uuid,uuid) to anon, authenticated;
