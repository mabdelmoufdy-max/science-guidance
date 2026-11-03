---
name: report-change
description: إضافة تقرير جديد أو تعديل تقرير موجود (أعمدة، فلاتر، ترتيب، دمج خلايا، صف مجموع، صلاحيات) في index.html لنظام توجيه العلوم، ثم اختباره وتجربته ونشره بالتسلسل المعتمد. استخدمه عند أي طلب يخص «تقرير» أو «تقارير المرحلة» أو الطباعة/Excel لقائمة معلمين أو مدارس.
---

# تعديل التقارير في نظام توجيه العلوم

الملف الوحيد: `index.html` (طبقات أغلفة `wrapper` فوق بعضها؛ **آخر تعريف يغلب**). اقرأ `CLAUDE.md` أولًا (القواعد الإلزامية). خلاصة التجربة (v256–v261) أدناه.

## 0) قبل أي تنفيذ (قاعدة 13 و11)
- اعرض الشكل المقترح **قبل البناء**: جدول نصي، أو صورة HTML مصوّرة بـPlaywright وتُرسل بـ`SendUserFile` (أسماء افتراضية، لا بيانات حقيقية).
- اذكر الافتراضيات واسأل فقط عمّا يغيّر السلوك (ترقيم مستمر؟ أعمدة تبقى؟ نطاق الأدوار؟). ثم «نفذ».
- لا قاعدة بيانات ولا صلاحيات جديدة دون طلب. التسلسل: تعديل ← اختبار الجزء المتأثر ← تجربة ← **«انشر» من المستخدم**.

## 1) خريطة الكود (ابحث بـgrep، لا تقرأ الملف كله)
- تعريف التقرير: `STATISTICS_REPORTS[id]` (title, subtitle, icon, adapter, filters, `purpose:true`, `statuses`, `statusLabel`) + `V103_PURPOSE_REPORTS.push(id)`.
- المصدر: `ReportAdapters[id]={async load(ctx){…return v103BaseReport(id,ctx,columns,rows,subtitle)}}`. صف التقرير يحمل حقول العرض + حقول الفلترة: `_schoolId,_schoolIds,_school,_schools,_stage,_stages,_status,_search`.
- فلترة تقارير `purpose`: غلاف `applyCurrentFiltersToReportSchema` في v103 — «المدرسة/معرف المدرسة/المرحلة» من المصفوفات `_schools/_schoolIds/_stages`، و«الحالة» من `row._status` (لذلك فلتر «التخصص» = `_status` + `statusLabel`).
- المقاييس بعد الفلترة: غلاف `v103RebuildMetrics` (مثال: `v238Metrics`, `v257Metrics`) — يُستدعى عند التحميل وبعد كل فلترة، فاجعله **قابلًا للتكرار** (idempotent).
- شاشة الفلاتر: `v103Detail(cfg,data)` (للتقارير `purpose`؛ لها فرع خاص `cfg.secOnly` مثالًا). حالة الفلاتر: `statisticsFilterStateFromUi` + `v103FilterState`.
- الصلاحيات: غلاف `v103CanViewReport` (أضف غلافًا جديدًا بقائمة أدوار؛ لا تعدّل القديم).
- العرض: `renderReportSchema` (يدعم صفوف `{_group:true,_groupTitle}` وصف `schema.totalRow`)، وأغلفته (`v259Spans` لدمج الخلايا بعد العرض).
- Excel: `v179ExportReport` (لا دمج؛ يكرر القيم؛ صف `totalRow` يُضاف).

## 2) أنماط جاهزة (استعملها بدل اختراع جديد)
- **صف المجموع** (`v256`): تلقائي لكل تقرير فيه أعمدة رقمية جمعية؛ يستثني `timetable|teacherSelf` وأعمدة «م/نسبة/ترتيب/رقم/كود/هاتف» وما فيه <2 صف. لا تضف أعمدة رقمية بلا داعٍ لأنها تُفعّله.
- **دمج الخلايا عموديًا**: لا تعتمد على دمج v239 (محرك عام قد يعيد بناء الأعمدة)؛ استثنِ تقريرك في `V239_SKIP_RE` واكتب دالة بعد `renderReportSchema` تدمج بـ`rowSpan` **من آخر عمود لأول عمود** (حتى لا تنزاح الفهارس) داخل كل `table`، وباعتماد مفتاح مركّب (مثل التخصص|المدرسة) كي لا يمتد الدمج عبر مجموعتين.
- **أقسام/عناوين مجموعات**: صفوف `_group` تُعاد بناؤها في دالة المقاييس بعد كل فلترة (لا تبنِها في `load` لأن الفلاتر تسقطها).
- **ترتيب الأقدمية** (`v261`): `teacher_supervision_priority.general_priority` (1 = الأقدم)؛ `v261Reorder(schema,groupKeyFn,idKey)` داخل كل مجموعة مع بقاء ترتيب المجموعات؛ من بلا ترتيب في آخر مجموعته. لا تخمّن تواريخ.
- **تحديد التخصص**: بالمادة المدرَّسة فعلًا (`teaching_assignments.curriculum_subjects.subject_name`) لا بـ`specialty`.
- المرحلتان «ثانوي عام» و«ثانوي صناعي» منفصلتان (يبدأ الاسم بـ«ثانوي»).

## 3) الاختبار (الجزء المتأثر فقط، ببيانات وهمية)
- Playwright من `/opt/node22/lib/node_modules/playwright`؛ اعترض `**/@supabase/supabase-js**` بمكتبة وهمية، وأحبط بقية `https://**`.
- افتح `file:///home/user/science-guidance/index.html`، ثم داخل `page.evaluate`: عيّن `activeTerm={id:'T'}` و`profile={role:'admin'}`، واستبدل `sb.from=t=>query` (select/eq/like/order/range ← `{data,error}`) ببيانات وهمية.
- استدعِ: `await ReportAdapters.x.load({period:reportPeriod(),issuer:reportIssuer()},{})` ← `applyCurrentFiltersToReportSchema(raw,state)` ← `renderReportSchema(schema,div)` واقرأ `tbody tr` و`rowSpan`. اختبر: بلا فلتر، فلتر مرحلة/مدرسة/حالة، 70+ صفًا (صفحات)، وأدوار الصلاحية (`v103CanViewReport` لـ7 أدوار).
- لا تدّعِ نجاحًا لم تفحصه؛ البيانات الحقيقية تحتاج حساب المستخدم — اذكر ذلك صراحة.

## 4) الإصدار والتسليم
- `<title>…vNNN</title>` يزيد مع كل نشر (وظيفي)، وتعليق `<!-- vNNN: … -->` أعلى الملف، وأقدم تعليق يُنقل إلى `CHANGELOG.md` (الحد 10).
- التجربة: انسخ إلى `trial/<name>/index.html` بتعديل `./manifest.webmanifest`, `./icon-192.png`, `register('./service-worker.js'` إلى `../../…`؛ الرابط ينتهي بـ`index.html`. الدفع إلى `main` يحتاج إذنًا؛ فرع الجلسة وحده لا يخدم GitHub Pages.
- **النشر بعد «انشر» فقط:** `git fetch origin main` والتأكد أن `origin/main` سلف لـHEAD (وإلا ادمج)، تحديث سطر الحالة في `CLAUDE.md`، `git push origin HEAD:main`، ثم `mcp__github__actions_list` (`list_workflow_runs`) للتحقق أن `head_sha` هو commit النشر؛ وإن كان `queued` فقل ذلك بصدق واطلب Ctrl+F5 وفحص رقم الإصدار.
- الرد دائمًا بالعربية، وآخره: مصدر النسخة، التعديل، ما اختُبر، وما لم يُحسم. لا تقترح تحسينات شكل جانبية.

## 5) ملاحظات من التجربة
- طلب «انشر» يدفع فرع الجلسة كله إلى `main` (قد يصاحبه ملفات غير مقصودة مثل عروض/تجارب) — نبّه المستخدم أو ادفع الملفات المقصودة فقط.
- رسائل واتس للمنسق: قصيرة، تذكر مكان التقرير والفلاتر وCtrl+F5 ورقم الإصدار، وما لم يتغير.
- ما هو خارج النطاق يُسجَّل في الرد ولا يُنفَّذ (مثل ترتيب تقرير إسناد مدرسة واحدة `v174AssignmentReport`).
