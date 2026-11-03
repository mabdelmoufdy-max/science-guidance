---
name: portals-deploy
description: تعديل ونشر بوابة المعلمين (vercel-portal) وصفحة الاعتماد (vercel-admin) وصفحة «إدخال بيانات المدارس» (/coordinator) وربط البرنامج بنطاق البوابة /app/، على Vercel. استخدمه عند طلب تعديل أي من هذه الصفحات أو vercel.json أو التنقل بين البرنامج والبوابات.
---

# البوابات الثلاث وربطها (Vercel)

## الخريطة
- **البرنامج الرئيسي:** `index.html` على `main` (GitHub Pages) ويُفتح رسميًا من `teachers-data-portal.vercel.app/app/` (rewrites من `vercel.json` إلى github.io؛ الرابط القديم github.io يحوّل إليه، و`?stay` للبقاء).
- **بوابة المعلمين:** `vercel-portal/index.html` (مصدرها المنشور)، مشروع Vercel `teachers-data-portal` (`prj_6W025MD7Ij2oz6oG2iLHrt7tKDou`، فريق `team_QQ1RCti9XCAtt88wlVbQpxHz`). شاشاتها: معلم (مسجل/جديد)، مشرف مدرسة، زر منسق، زر البرنامج، رابط مباشر `/#teacher`.
- **«إدخال بيانات المدارس»** (كان «صفحة المنسق»): `trial/coordinator-entry/index.html` على `main`، تُخدم من البوابة عبر rewrite `/coordinator(/)` ← GitHub Pages (تحديثها لا يحتاج إعادة نشر البوابة). للمنسق وadmin فقط.
- **صفحة الاعتماد:** `vercel-admin/index.html` ← `teacher-portal-admin.vercel.app` (للمالك فقط).

## `vercel.json` (نقاط حساسة)
- `redirects`: `/app` ← `/app/`؛ `rewrites`: `/app/`, `/app/:path*` ← github.io؛ أولها `/app/manifest.webmanifest` ← `/app-manifest.webmanifest` (نطاق `scope:"/"` + أيقونات maskable).
- الرؤوس: القاعدة العامة `no-store`، وبعدها (الأخيرة تغلب) `/app/(.*)` و`/coordinator(.*)` ← `no-cache`.
- الإطارات: `X-Frame-Options: DENY` عام؛ استثناء `SAMEORIGIN` لـ`/coordinator(.*)` فقط (لعرضها داخل البرنامج بـ`?embed=1`).
- روابط التجربة على نطاق البوابة **تنتهي بـ`index.html`** وإلا 404.
- جلسة Supabase محفوظة لكل نطاق؛ لذا الدخول من `/app/` والبوابة جلسة واحدة، ومن github.io جلسة منفصلة.

## النشر (بعد «انشر» فقط)
1. ادمج آخر `main` ثم ادفع إلى `main`.
2. `mcp__Vercel__create_deployment` بـ`gitSource` (github، org/repo، ref + sha) و`projectSettings.rootDirectory:"vercel-portal"` (أو `vercel-admin` لصفحة الاعتماد)، ثم `update_project` بـ`rootDirectory:null` لإعادتها.
3. المعاينات محمية بـVercel SSO؛ للتحقق أعطِ المستخدم رابط مشاركة (`get_access_to_vercel_url`، 23 ساعة). الإنتاج: redeploy بـ`target:production` (ترقية معاينة مباشرة تُرفض 422).
4. تحقق: `/` مطابق للمصدر، `/coordinator/` = ملف GitHub، ورؤوس الملفات المتغيرة.
5. لا تدّعِ نجاحًا لم تفحصه؛ التطبيق المثبّت على الهاتف قد يتأخر يومًا في التحديث.

## تغييرات سابقة تؤثر على أي تعديل
- شريط التطبيق المثبّت: manifest بـ`scope:"/"` يبقي «إدخال بيانات المدارس» داخل النافذة.
- زر «🔗» في البرنامج (قائمة البوابات) وزر «🖥 البرنامج» في صفحة الإدخال وزر «البرنامج الرئيسي» في البوابة.
- تبويب «معلم جديد» في بوابة المعلمين مفعّل؛ الرابط `#teacher` مباشر.
- الحقول/الشاشات التي تغيّرها البوابة تعتمد دوال قاعدة بيانات؛ انظر skill `teacher-portal-db` قبل تغيير سلوك الإرسال.
