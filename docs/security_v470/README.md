# v470 — سد وصول الحسابات بلا دور (أمان)

| الملف | الغرض |
|---|---|
| `function-audit.md` | المراجعة الأصلية (أعداد فقط) |
| `v470_close_roleless_access_2026-11-26.sql` | الإصلاح — معاملة واحدة؛ يتوقف عند أي عدم تطابق؛ يرفض التشغيل مرتين (`V4701`)؛ يتحقق أن `audit_log.id` bigint (`V4703`) |
| `rollback_v470_close_roleless_access_2026-11-26.sql` | رجوع حرفي من `private.v470_backup` + حذف سطر التدقيق الخاص بالإصلاح (يجب أن يكون واحدًا بالضبط، وإلا `V4702`) + حذف جدول النسخة |
| `setup_test_db_v470.sql` | يضع علامة قاعدة الاختبار `v470_test_marker.marker` (لا توجد على الإنتاج) |
| `fixtures_v470.inc.sql` | بيانات اصطناعية مشتركة (9 حسابات، معلمان، رقمان قوميان وهميان) — تُضمَّن داخل معاملة تُلغى |
| `tests_v470_2026-11-26.sql` | اختبارات assertion (`phase=before|after`) |
| `snapshot_v470.sql` | بصمات md5: تعريفات وملاك وصلاحيات الكائنات الأربعة + صفوف/استجابات الأدوار المصرّح لها |
| `verify_restore_v470.sql` | أعداد للتحقق من اكتمال الاستعادة (يُقارن ناتج الإنتاج بناتج الاختبار) |
| `tests_cycle_v470_2026-11-26.sh` | الدورة الكاملة (انظر §4) |

**لم يُنفَّذ شيء على الإنتاج.** شرط التنفيذ: موافقة مالك المشروع الصريحة + pg_dump محدّث + `CYCLE PASS` على قاعدة اختبار مستعادة من الإنتاج.

## ماذا يتغير
1. `teacher_workload_summary` (ومعه `teacher_official_staffing` الذي يقرأ منه): `WHERE role IS NOT NULL AND (role <> 'teacher' OR profile_id = auth.uid())` — شرط الدور يلف الطرفين.
2. `school_supervisor_choice.ssc_read`: `using (current_app_role() is not null)`.
3. `lookup_identity_by_civil`: يعمل فقط لـ `admin`, `stage_coordinator`, `supervisor` **و`senior_teacher`**؛ غيرها (`teacher`, `first_supervisor`, `school_manager`، بلا دور) ← `{valid:false, exists:false}`.
   - **استثناء مقصود — `senior_teacher` («حساب المدرسة»):** ليس في جدول المراجعة، لكنه مُبقى عمدًا لأن شاشة «إضافة معلمين بسرعة» (`index.html`: `seniorTeacherAddTeacherForm` ← `uxSmartifyForm` ← `uxLookupCivil`، قرب السطر 7122) تستدعي الدالة بهذا الدور؛ حذفه يكسر الشاشة. السبب نفسه مكتوب كتعليق داخل الدالة بعد التطبيق. الاختبار `3 senior_teacher lookup allowed` يثبت بقاءه، و`3 first_supervisor lookup rejected` و`3 school_manager lookup rejected` يثبتان رفض أي دور آخر.
   - بقية المسارات: `openCreateUser` (إنشاء حساب: مدير/منسق)، `teacherAccountForm` (إضافة معلم سريعة: موجه).
4. `audit_log.audit_insert`: `actor_profile_id = auth.uid() AND current_app_role() is not null`.

## من يستخدم الكائنات (من قراءة `index.html` على هذا الفرع)
| الكائن | الأماكن | الأثر المتوقع |
|---|---|---|
| `teacher_workload_summary` | ~4336 بيانات المعلم، 6589 تقرير «المعلمون»، 7804 صفحة المعلمين، 15799 و17529 قائمة المجازين | لا شيء (المستخدمون بدور نشط) |
| `school_supervisor_choice` | ~11059 اختيار المشرف، ~17370 صفحة تعديل المعلم | لا شيء |
| `lookup_identity_by_civil` | 7102 `uxLookupCivil` ← الشاشات الثلاث أعلاه | لا شيء للأدوار الأربعة |
| `audit_log` إدراج مباشر | لا يوجد من الواجهة؛ دوال الحافة بمفتاح الخدمة (تتجاوز RLS) | لا شيء |

## 1) نسخة احتياطية (جهاز مالك المشروع، ويندوز، cmd)
```
cd "C:\Program Files\PostgreSQL\17\bin"
pg_dump -Fc -f C:\Backup_Supabase\before_v470_YYYY-MM-DD.dump <رابط Session pooler>
pg_restore -l C:\Backup_Supabase\before_v470_YYYY-MM-DD.dump | find /c "TABLE DATA"
```
بلا `--no-owner`/`--no-privileges` حتى تحمل النسخة الملاك والصلاحيات. المتوقع: رقم ≈ 248 أو أكثر. انسخ الملف إلى Google Drive خاص. لا تلصق الرابط (فيه كلمة السر) في أي محادثة.

## 2) قاعدة اختبار تحفظ الأدوار والملاك والصلاحيات (Postgres 17)
يحتاج خادم PostgreSQL 17 محليًا (مُثبِّت ويندوز مع مكوّن **PostgreSQL Server**) أو أي خادم 17 تملكه — **ليس الإنتاج**.
1. **الأدوار أولًا** (من الإنتاج، بلا كلمات مرور):
   `pg_dumpall --roles-only --no-role-passwords -d <رابط الإنتاج> -f C:\Backup_Supabase\roles_v470.sql`
   ثم على الخادم المحلي: `psql -U postgres -f C:\Backup_Supabase\roles_v470.sql` (أخطاء «role already exists» لـ postgres مقبولة؛ المهم أن تُنشأ `anon`, `authenticated`, `service_role`, `authenticator`, `supabase_admin`, `supabase_auth_admin`, `supabase_storage_admin`…).
2. `createdb -U postgres v470_test`
3. الاستعادة **بالملاك والصلاحيات** (بلا `--no-owner` ولا `--no-privileges`)، والسجل خارج المستودع:
   `pg_restore -U postgres -d v470_test C:\Backup_Supabase\before_v470_YYYY-MM-DD.dump 2> %USERPROFILE%\.v470-test-logs\restore.log`
   أخطاء امتدادات Supabase غير المتوفرة محليًا (`pg_graphql`, `pg_net`, `pg_cron`, `supabase_vault`, `pgsodium`) متوقعة ولا تمس `public`/`private`.
4. **العلامة قبل أي كتابة:** `psql -U postgres -d v470_test -f docs/security_v470/setup_test_db_v470.sql`
5. **تحقق الاستعادة بالأعداد:** شغّل `verify_restore_v470.sql` على الإنتاج (قراءة فقط، من SQL Editor أو psql) ثم على `v470_test`، وقارن الناتجين: يجب أن تتطابق كل الأسطر (جداول، views، دوال، policies، GRANTs، RLS، ملاك الكائنات الأربعة، بصمة صلاحياتها وتعريفاتها). أي فرق = لا تكمل.

## 3) Advisors قبل وبعد
قبل التطبيق على الإنتاج: لوحة Supabase ← **Advisors ← Security Advisor** ← Refresh ← انسخ **أسماء التنبيهات وأعدادها فقط** إلى `advisors_before.txt` (خارج المستودع). بعد التطبيق: نفس الخطوة ← `advisors_after.txt` ← قارن. المتوقع: لا تنبيه جديد (`private.v470_backup` في schema غير مكشوفة). (أو `get_advisors type=security` للقراءة فقط.)

## 4) الدورة على قاعدة الاختبار (من جذر المستودع، Git Bash أو Linux)
```
TEST_DB='host=localhost port=5432 dbname=v470_test user=postgres' docs/security_v470/tests_cycle_v470_2026-11-26.sh
```
تسلسلها: علامة ← سطر تدقيق حارس ← بصمة أولى ← اختبارات `before` ← تطبيق ← تطبيق ثانٍ (يجب `V4701` وحده) ← اختبارات `after` ← بصمات الأدوار المصرّح لها مطابقة ← رجوع ← (جدول النسخة غائب، سطر التطبيق محذوف، الحارس سليم، كل البصمات = الأولى) ← `before` ← تطبيق ← `after` ← رجوع ← نفس الفحوص ← حذف الحارس.
- المتوقع آخر سطر: `CYCLE PASS`.
- الشاشة: اسم الاختبار PASS/FAIL وكود SQLSTATE فقط. السجل الكامل (قد يحوي نصوص أخطاء Postgres) في `~/.v470-test-logs/` خارج المستودع (ومُدرج في `.gitignore` احتياطًا). لا يلزم حفظ ناتج الشاشة.
- يرفض: رابطًا فيه معرّف مشروع الإنتاج (`REFUSED prod-ref`)، قاعدة بلا العلامة (`V47T0` / `FAIL no-test-marker`).
- أكواد: `V47F0` فشل اختبار، `V47T0` ليست قاعدة اختبار، `V4701` مطبّق مسبقًا، `V4702` عدد أسطر التدقيق المحذوفة ≠ 1، `V4703` نوع id، `V4704` رجوع بلا تطبيق.
- إن فشل `F1 fixture rows visible…`: سجل المعلم الاصطناعي لا يظهر في العرضين بالقاعدة الحقيقية — راجع الشروط في رأس `fixtures_v470.inc.sql` (active، work_type، home_school_id) وأكمل الأعمدة الإلزامية هناك فقط.

## 5) التطبيق على الإنتاج (بعد الموافقة فقط)
1. SQL Editor: https://supabase.com/dashboard/project/xehjwzszhsaqdqmcatum/sql/new
2. الصق `v470_close_roleless_access_2026-11-26.sql` ← Run. المتوقع: `Success. No rows returned`. أي رسالة `v470: …` = توقف ولم يتغير شيء.
3. Advisors (§3).
4. فحص يدوي في البرنامج (Ctrl+F5):
   - [ ] مدير: صفحة «المعلمون» تعرض العدد المعتاد.
   - [ ] مدير: تقرير «المعلمون/أنصبة المعلمين» يفتح بنفس العدد.
   - [ ] منسق: «تعديل بيانات المعلم» لمعلم في مرحلته يفتح ويحفظ تعديلًا بسيطًا (يكتب تدقيقًا).
   - [ ] منسق/مدير: اختيار مشرف المادة لمدرسة يُظهر المشرف الحالي.
   - [ ] منسق: «إضافة معلم» برقم قومي موجود ← رسالة «مسجّل».
   - [ ] موجه: «إضافة معلمين بسرعة» يتعرّف على رقم موجود.
   - [ ] حساب مدرسة (senior_teacher): «إضافة معلمين بسرعة» يتعرّف على رقم موجود.

## 6) الرجوع
`rollback_v470_close_roleless_access_2026-11-26.sql` في SQL Editor (يحوي أمر حذف لسطر تدقيق الإصلاح، فلا يُشغَّل عبر أداة Claude). المتوقع: `Success`. بعده يمكن إعادة التطبيق.

## فحص الأمان (قاعدة 15)
(أ) لا مفاتيح ولا كلمات سر ولا بيانات حقيقية (الأرقام القومية والمعرّفات في الاختبار اصطناعية). (ب) لا دالة SECURITY DEFINER جديدة؛ المعدّلة تحتفظ بـ search_path وتضيف تحققًا. (ج) `private.v470_backup` في private ومقفول ويحذفه الرجوع؛ `v470_test_marker` يوجد على قاعدة الاختبار فقط. (د) العرض يضيّق فقط. (و) لا توسيع لأي صلاحية. (ز) Advisors §3.

## ما اختُبر وما لم يُختبر
- ✅ الدورة كاملة `CYCLE PASS` على **Postgres 16 محلي بقاعدة بديلة** تحاكي العرضين والدالة والسياستين بنفس نصوص الشروط.
- ✅ اختبارات الطفرة (كل طفرة أفشلت الدورة): شرط الدور على طرف واحد ← `FAIL 2a`؛ lookup بلا قائمة أدوار ← `FAIL 1d`؛ حذف senior_teacher ← `FAIL 3 senior_teacher lookup allowed`؛ إضافة first_supervisor ← `FAIL 3 first_supervisor lookup rejected`؛ سياسة تدقيق بلا شرط الدور ← `FAIL 4a`؛ رجوع لا يحذف سطر التطبيق ← `V4702`؛ رجوع لا يعيد الدالة ← `FAIL definitions-or-fingerprints-differ-after-rollback`؛ تطبيق ثانٍ بخطأ غير مقصود ← `FAIL apply-twice codes=[P0001]`؛ قاعدة بلا علامة ← `V47T0`/`FAIL no-test-marker`؛ رابط الإنتاج ← `REFUSED prod-ref`.
- ❌ **مفتوح:** لم تُشغَّل الدورة على Postgres 17 بتعريفات الإنتاج الحقيقية (غير متاح في بيئة الكتابة). المخاطر: اختلاف نص `pg_get_viewdef`/`begin` الحقيقي (يتوقف الإصلاح بأمان)، أعمدة إلزامية إضافية للبيانات الاصطناعية (`F1` يكشفها)، ومنطق `current_app_role` الحقيقي (الاختبارات تتحقق منه صراحةً في كل جلسة).
- ❌ **مفتوح:** `index.html` على هذا الفرع مطابق لـ `origin/main` (0 أسطر فرق، `main` = 139a448، 2026-11-26)، لكن لم يُتحقق أن النسخة المنشورة فعليًا تطابق `main` (الشبكة هنا تمنع `github.io`) — تحقّق بفتح البرنامج والتأكد من رقم الإصدار في العنوان.

## الحالة على الإنتاج (2026-11-26)
- **البند 1 فقط طُبّق** بأمر واحد من SQL Editor بواسطة مالك المشروع (تعديل شرط `teacher_workload_summary` بإضافة `role IS NOT NULL` حول الطرفين؛ بلا تغيير صلاحيات).
- تحقق قراءة فقط: حساب بلا دور 434 ← **0** في العرضين؛ المدير 434 بلا تغيير. فحص بالعين: صفحة «المعلمون» وتقرير المعلمين بحسابي مدير ومنسق — الأعداد كما كانت.
- الرجوع للبند 1: أمر `do $$ … replace(d, cur, old) … $$` (يعيد الشرط القديم) — لا يعتمد على `private.v470_backup`.
- البنود 2–4 (`ssc_read`، `lookup_identity_by_civil`، `audit_insert`) **لم تُطبَّق**؛ ملف v470 الكامل لا يُشغَّل الآن (سيتوقف لأن شرط العرض تغيّر).
