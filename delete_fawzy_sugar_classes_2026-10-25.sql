-- إلغاء إسناد فصلي فوزي احمد ابراهيم في مصنع السكر ع (3/6 و2/6) — شغّله من Supabase SQL Editor.
delete from public.teaching_assignments where id in ('d118cd4f-f1c9-4497-8ab2-d77784c53d1a','044b8a43-94c5-4514-961a-4434fb4fbf05') and teacher_id='e4051a08-3165-4216-a08a-075fe4e7dddb';
-- تعطيل تسجيله غير الأصلي في مصنع السكر ع
update public.teacher_school_assignments set active=false where teacher_id='e4051a08-3165-4216-a08a-075fe4e7dddb' and is_home_school=false and school_id='a33d9d52-4dd9-4579-86e5-248f5c92d76e';
