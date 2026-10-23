-- Rollback: class assignments entered 2026-10-23 from teachers' messages
-- فاطمة محمد القاسم محمود: الجمالية تعليم اساسي 1/1، 2/1، 3/1 — فهد هاشم احمد: عمر بن عبدالعزيز 2/2..2/6
-- Run from Supabase SQL Editor.
delete from public.teaching_assignments ta
using public.teacher_records tr, public.school_classes c, public.schools s
where ta.teacher_id=tr.id and ta.class_id=c.id and c.school_id=s.id
  and ((tr.full_name='فاطمة محمد القاسم محمود' and s.name='الجمالية تعليم اساسي' and c.class_name in ('1/1','2/1','3/1'))
    or (tr.full_name='فهد هاشم احمد' and s.name='عمر بن عبدالعزيز' and c.class_name in ('2/2','2/3','2/4','2/5','2/6')));
