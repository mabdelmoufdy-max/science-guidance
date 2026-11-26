# مراجعة دوال وجداول public المتاحة لـ authenticated — برومبت 1.2ج (قراءة فقط)

> 2026-11-26، مشروع «توجيه العلوم». كل الاستعلامات `begin read only`. لم يُنفَّذ أي تعديل أو GRANT/REVOKE.
> **طريقة الاختبار:** حصر آلي لكل الدوال + قراءة الكود + **محاكاة فعلية** لموظف مدرسة: جلسة بدور `authenticated` ومعرّف مستخدم وهمي ليس له أي سطر في `profiles`/`user_roles`، مع ترويسة مزيفة `x-app-role: admin` (أسوأ حالة). لم تُكتب بيانات شخصية في هذا الملف.

## الخلاصة
| | العدد |
|---|---|
| دوال public متاحة لـ authenticated أو anon | 175 (منها 17 دالة trigger لا تُنادى مباشرة) |
| SECURITY DEFINER منها | 137 — **كلها لها `search_path` مضبوط** ✅ |
| الدور المزيف في الترويسة | **لا يُقبل**: `current_app_role()` = NULL لحساب بلا أدوار ✅ |
| **ثغرة عالية** | **1** (عرض `teacher_workload_summary`) |
| متوسطة | 2 |
| منخفضة | 4 |

## 1) خطر عالي 🔴
### `public.teacher_workload_summary` (عرض) + `public.teacher_official_staffing` (عرض يقرأ منه)
- **المحاكاة:** حساب المدرسة الوهمي قرأ **434 صفًا** فيها `civil_id` و`full_name` و`profile_id` والمدرسة والدرجة والأنصبة لكل معلمي توجيه العلوم.
- **السبب:** شرط العرض
  `WHERE current_app_role() IS DISTINCT FROM 'teacher' OR profile_id = auth.uid()`
  — لحساب بلا دور `current_app_role()` = NULL، و`NULL IS DISTINCT FROM 'teacher'` = **true** ⇒ كل الصفوف.
- العرض ليس `security_invoker` فلا تحميه RLS جداول المعلمين.
- **ثغرة قائمة اليوم** (ليست بسبب smart-school): أي حساب في المشروع فقد أدواره أو عُطّلت أدواره يرى الكل. مع الخيار (أ) تصبح متاحة لكل موظفي المدرسة.

## 2) متوسط 🟠
| العنصر | ما يحدث لحساب المدرسة |
|---|---|
| `school_supervisor_choice` (جدول، سياسة `ssc_read` = `true`) | يقرأ 110 صفوف: المدرسة، المعلم (معرّف)، ملاحظة الموجه، من اختار ومتى. بلا أسماء لكنها ملاحظات إدارية داخلية. |
| `lookup_identity_by_civil(civil)` | لا يعيد الاسم أو الهاتف، لكن يعيد `exists/teacher_exists/supervisor_exists/has_profile` ⇒ يكشف هل رقم قومي معيّن مسجّل كمعلم/موجه (أداة تخمين). |

## 3) منخفض 🟡
| العنصر | الأثر |
|---|---|
| `academic_years`, `terms`, `workload_rules`, `curriculum_subjects` | قراءة بيانات مرجعية عامة (لا أشخاص). |
| `get_reports_dataset` | يعيد `rules` (20 قاعدة نصاب) وكل الباقي فارغ. |
| `dup_ignore_list()` | يعيد مفتاحين لحالات تكرار «متجاهلة» (معرّفات، بلا أسماء). |
| `audit_insert` على `audit_log` | يستطيع إدراج سطور تدقيق باسمه هو فقط (إزعاج/تلويث للسجل، بلا قراءة). |
| `teacher_portal_schools()`، `log_login_failure`، دوال `teacher_portal_*` | مفتوحة لـ **anon** أصلًا بالتصميم (البوابة)؛ حساب المدرسة لا يضيف خطرًا جديدًا. محمية بالرقم القومي + الهاتف. |

## 4) سليمة ✅ (عيّنة ممّا جُرّب فعليًا)
- كل دوال `admin_*` (46) — بما فيها 4 ممنوحة لـ anon (`admin_portal_features`, `admin_set_portal_feature`, `admin_set_portal_preset`, `admin_portal_schedule_*`) — ترفض: «غير مصرح: هذه العملية لمدير النظام فقط».
- `get_school_teacher_roster(s)`, `get_assignment_workspace` ← «المدرسة خارج نطاق صلاحيتك». `get_school_teacher_rosters_all`, `get_delegation_periods`, `get_supervisor_hierarchy_data` ← فارغة. `timetable_progress` ← Unauthorized. `get_dashboard_stats` ← active role required. `teacher_portal_admin_*` ← forbidden. `statement_review_*` ← مرفوض.
- **الكتابة:** كل سياسات INSERT/UPDATE/DELETE في public مشروطة بـ `current_app_role()` أو `can_access_*` أو `timetable_can_manage` أو `v390_direct_school` (كلها NULL/false لحساب بلا دور)، عدا `audit_insert` أعلاه. كل دوال الكتابة SECURITY DEFINER تفحص الدور. الدوال INVOKER (`save_teacher_record_atomic`, `submit_school_for_approval_atomic`, `ensure_school_submission_in_progress_atomic`, `unassign_class_atomic`…) تمر عبر RLS فتُرفض.
- **الجداول:** RLS مفعّل على كل جداول public الـ126. من 48 جدولًا/عرضًا ممنوحًا لـ authenticated، ما يظهر لحساب بلا دور: `academic_years`(1) `terms`(2) `workload_rules`(25) `curriculum_subjects`(20) `school_supervisor_choice`(110) `teacher_workload_summary`(434) `teacher_official_staffing`(434). كل ما عداها = 0 صف.
- (لم تُجرَّب دوال الكتابة بالتنفيذ الفعلي لأن الجلسة للقراءة فقط؛ الحكم عليها من الكود والسياسات.)

## 5) الحلول المقترحة (لا تُنفَّذ إلا بموافقتك) — مرتبة بالأولوية
| # | الحل | الأثر على توجيه العلوم |
|---|---|---|
| 1 | **إصلاح `teacher_workload_summary`:** تغيير الشرط إلى `current_app_role() IS NOT NULL AND (current_app_role() <> 'teacher' OR profile_id = auth.uid())` (استبدال نصي للسطر فقط في migration، مع بصمة قبل/بعد). | **لا أثر** على المستخدمين الحاليين: الـ19 حسابًا النشطين لهم دور. حساب بلا دور (معطّل) يرى صفرًا بدل الكل. البوابة لا تقرأ العرض (دوالها SECURITY DEFINER). **لازم حتى لو اخترنا (ج)** لأنها ثغرة قائمة. |
| 2 | `school_supervisor_choice`: تغيير `ssc_read` من `true` إلى `current_app_role() IS NOT NULL` (أو `can_access_school(school_id)`). | الأول بلا أثر. الثاني قد يخفي صفوفًا عن شاشة تعرض المشرفين لمدارس خارج النطاق — يحتاج اختبار. أوصي بالأول. |
| 3 | `lookup_identity_by_civil`: إرجاع `{valid:false}` مبكرًا إن كان `current_app_role()` NULL أو ليس admin/منسق/موجه. | مستخدمة في نموذج إنشاء الحسابات للمدير — بلا أثر عليه. |
| 4 | `audit_insert`: إضافة `AND current_app_role() IS NOT NULL`. | بلا أثر (البرنامج يكتب التدقيق وهو بدور). |
| 5 | (اختياري) `REVOKE EXECUTE ... FROM anon` على `admin_portal_*` الأربع. | لا أثر — ترفض anon أصلًا من داخلها؛ تنظيف فقط. ⚠️ تأكد أن صفحة الاعتماد لا تناديها بلا دخول. |

> **ملاحظة للقرار بين (أ) و(ج):** مع (أ) يجب تنفيذ 1–4 **قبل** إنشاء أي حساب موظف مدرسة. ومع (ج) يُنصح بتنفيذ 1 على أي حال لأنه يحمي توجيه العلوم نفسه.
