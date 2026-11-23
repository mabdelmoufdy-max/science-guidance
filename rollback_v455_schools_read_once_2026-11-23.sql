-- استرجاع v455: إعادة سياسة قراءة المدارس كما كانت
alter policy schools_read on public.schools using (can_access_school(id));
