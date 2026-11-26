-- تجهيز قاعدة الاختبار — يُشغَّل مرة واحدة على قاعدة الاختبار بعد الاستعادة وقبل أي اختبار.
-- يضع علامة منفصلة (schema باسم واضح) لا توجد أبدًا على الإنتاج؛ كل ملفات الاختبار ترفض التشغيل بدونها.
-- لا تشغّله على الإنتاج.
\set ON_ERROR_STOP 1
\if :{?keep_verbosity}
\else
\set VERBOSITY sqlstate
\endif
begin;
create schema v470_test_marker;
create table v470_test_marker.marker(created_at timestamptz not null default now(), note text not null);
insert into v470_test_marker.marker(note) values ('قاعدة اختبار v470 — ليست الإنتاج');
revoke all on schema v470_test_marker from public;
commit;
