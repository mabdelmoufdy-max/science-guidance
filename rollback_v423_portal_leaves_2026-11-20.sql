-- استرجاع v423 (الإجازات في بوابة المعلمين). يُشغَّل من SQL Editor:
-- https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
-- يحذف الدوال الخمس ودالة السياق. لا يمس teacher_short_leaves (v421) — الإجازات المسجّلة من البوابة تبقى فيه.
-- الجدول teacher_long_leave_requests والعمود leaves_open يُتركان (بهما بيانات الطلبات)؛ احذفهما يدويًا إن أردت (السطران المعلّقان).
drop function if exists public.teacher_portal_leaves(text, text, uuid);
drop function if exists public.teacher_portal_short_leave_add(text, text, uuid, text, date, date, text);
drop function if exists public.teacher_portal_short_leave_cancel(text, text, uuid, uuid);
drop function if exists public.teacher_portal_long_leave_request(text, text, uuid, text, date, date, text);
drop function if exists public.teacher_portal_long_leave_withdraw(text, text, uuid, uuid);
drop function if exists private.v423_ctx(text, text, uuid);
-- drop table if exists public.teacher_long_leave_requests;
-- alter table public.teacher_portal_settings drop column if exists leaves_open;
-- عند النجاح: «Success. No rows returned».
-- إيقاف مؤقت بلا حذف (أفضل): update public.teacher_portal_settings set leaves_open = false where id = 1;
