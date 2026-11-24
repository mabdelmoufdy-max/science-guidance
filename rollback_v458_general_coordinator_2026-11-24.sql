-- استرجاع v458 «المنسق العام» — شغّله من SQL Editor:
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- لا يمس أي بيانات سابقة: v458 إضافي فقط (جدول + قدرة + 4 دوال).
-- ملاحظة: إن عُيّن منسق عام قبل الاسترجاع فإسنادات مراحله في stage_coordinator_assignments تبقى كما هي
-- (عدّلها من «تعديل الأدوار» في مركز التحكم إن أردت إعادتها لمرحلة واحدة).

-- 1) سحب الاستثناءات الممنوحة بالتعيين (تبقى في السجل كملغاة)
update public.permission_grants
   set revoked_at = now()
 where capability = 'cross.move_schools' and revoked_at is null;

-- 2) إزالة القدرة
delete from public.permission_capabilities where code = 'cross.move_schools';

-- 3) إزالة الدوال
drop function if exists public.coordinator_move_schools(uuid[], uuid, boolean, text);
drop function if exists public.admin_general_coordinators();
drop function if exists public.admin_set_general_coordinator(uuid, boolean, text);
drop function if exists public.my_coordinator_scope();
drop function if exists private.is_general_coordinator(uuid);

-- 4) إزالة الجدول
drop table if exists public.general_coordinators;

-- المتوقع عند النجاح: «Success. No rows returned».
-- تحقق: select count(*) from permission_capabilities;  -- يعيد 15
