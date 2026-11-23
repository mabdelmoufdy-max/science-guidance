-- v455: سياسة قراءة المدارس تحسب المدارس المسموحة مرة واحدة للطلب (نفس النتيجة، أسرع)
alter policy schools_read on public.schools using (id in (select unnest(private.accessible_school_ids())));
