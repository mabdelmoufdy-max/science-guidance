# جرد المرحلة ب قبل v447

المرجع هو main عند b135727. فُحص index.html وقرئت تعليمات AGENTS.md وخطة البوابة. راجعت الاستدعاءات المباشرة، ومعالجات onclick، ومفاتيح القوائم والمسارات والتقارير، ومحددات CSS، وأسماء الدوال المحفوظة في الأغلفة والمصفوفات.

الحجم الأساسي 17,237 سطرًا، و1,904.289 كيلوبايت، أو 573.811 كيلوبايت مضغوطًا بـ gzip -n -9. الكيلوبايت = 1000 بايت. القياس يشمل الأسطر المشار إليها كاملة، ولو كان المرشح فرعًا داخل سطر مشترك. البنود قد تتداخل، فلا تُجمع الأحجام.


## أ — أجزاء خاصة بالدورين

| العنصر | أسطر index.html | القياس التقريبي | خطر الحذف | المراجع وحدود النطاق |
|---|---|---:|---|---|
| لوحة إدارة القسم وتلميح تبديل المعلم إلى مشرف المادة | 2506-2507 | 2 سطر / 1.67 كيلوبايت | متوسط | الشرطان داخل dashboardPage خاصان بالدورين. الإدراج عند 2508. selectRole مشترك ويُستبقى. |
| CSS للوحة إدارة القسم وأزرارها | 1173-1180,1224-1241 | 26 سطر / 1.50 كيلوبايت | منخفض | markup الوحيد 2506. جمع إجراءات الهاتف يذكر .supervisor-tools-grid و.tool-icon عند 5829 و5834، وهما داخل دالة مشتركة. تُستبقى القواعد المجاورة. |
| myAssignmentsPage، صفحة حصصي وفصولي | 4174-4186 | 13 سطر / 3.00 كيلوبايت | متوسط | من NAV.teacher وإجراء الهاتف، وتسجيلها في loadPage. تستخدم myTeacherRecord. لها غلاف 11065-11070. |
| غلاف حصصي وفصولي وإدماج الجدول | 11065-11070 | 6 سطر / 0.46 كيلوبايت | متوسط | العلم __v161EmbedTimetable له قارئ في 8610، وصفحة teacherTimetablePage نفسها مشتركة. إزالة الغلاف مرهونة بمراجعة القارئ. |
| مدخلات myAssignments في المساعدة ومسار الصفحة والتقارير وفلاتر المرحلة | 2834,3076,6339,8097 | 4 سطر / 1.19 كيلوبايت | متوسط | المفاتيح وحدها خاصة بالصفحة، مع بقاء المحوّل distribution وباقي السجلات. |
| v160Date وv160Val وv160Sections وv160TeacherSelfPage | 7582-7583,7594-7612 | 21 سطر / 3.38 كيلوبايت | متوسط | عرض الملف الذاتي من غلافي 7618-7619 و11059-11064. v160Val وv160Sections يستخدمهما أيضًا محوّل teacherSelf في قسم ج، فلا يُحذفان وحدهما. v160LoadSelf مستثناة. |
| فرعا الملف الذاتي في غلافي teachersPage وdashboardPage | 7618-7619,11059-11064 | 8 سطر / 0.55 كيلوبايت | متوسط | العمل الخاص بالمعلم حصري، لكن الغلاف يمرر بقية الأدوار إلى الأصل. لا يوافق هذا الصف على حذف تعريف الغلاف كاملًا أو إعادة ترتيب السلسلة. |
| seniorTeacherAddTeacherForm وcreateSchoolTeacher | 6964-6968,6989 | 6 سطر / 2.49 كيلوبايت | متوسط | المراجع 2506 و3577 و5821، ومحدد CSS 2014 وV293_EDIT_RE ‏13691 وV360_FUNCS ‏15098. نموذج fastTeacherForm خاص بحساب المدرسة. uxCreateTeacherSequence مشترك مع الموجه. |
| فرع إرسال حساب المدرسة للاعتماد وsubmitSchool وغلافه | 4619-4628,4632-4636,7087 | 16 سطر / 4.13 كيلوبايت | متوسط | استدعاء الفرع 4625، ومراجع 2014 و13691 و15103. يُستبقى اعتماد الموجه، وapproveSchool وpreviewApprovalDistribution. |
| اختصارا الدورين في mobileDefaultActions | 5821-5822 | 2 سطر / 0.42 كيلوبايت | منخفض | الفرعان فقط. إعدادات اختصارات بقية الأدوار في الدالة نفسها تبقى. |
| إدخالا الدورين في V307_ORDER | 13965-13966 | 2 سطر / 0.29 كيلوبايت | منخفض | v307Order عند 13968 مشترك، ويستخدمه عرض الواجهة والمساعدة. تعديلات أدوار أخرى عند 14050 و14719 و15997 و16375. |
| فرع كلمة مرور المعلم، غلاف v339 للرئيسية | 14266-14272 | 7 أسطر / 1.12 كيلوبايت | متوسط | يُستدعى في dashboardPage ويضيف النموذج للمعلم فقط. v270ChangePassword ونموذج الموجه عند 3912 و3944 مشتركان. لا توجد قواعد مستقلة لـv339-mypw. |
| جهة حساب المدرسة من v293، وتشمل NAV_BASE وV293_EDIT_RE وReadOnly وApplyNav وLoad وMsg وBanner وChip ومستمع النقر | 13690-13701,13703-13721 | 31 سطر / 3.29 كيلوبايت | متوسط | ترتبط بأغلفة عامة في 13722-13729. v293OfficerText عند 13702 مشترك، وكذلك تعريف الحالة الذي يجمع v293Info وv293Sup عند 13689. يُستبقى الجزء الخاص إلى حين اعتماد فصل الأغلفة. |
| CSS المقيد بـbody.v293-ro وشارة v293-chip | 2014-2016 | 3 سطر / 1.71 كيلوبايت | منخفض | الفئة تُضبط في 13696 والشارة تُنشأ في 13711-13715. الأزرار المذكورة داخل المحددات بعضها مشترك. |

## ب — أجزاء مشتركة تُستبقى

| العنصر | أسطر index.html | القياس التقريبي | خطر الحذف | المراجع وحدود النطاق |
|---|---|---:|---|---|
| شاشة القفل v446 ودورة الدخول | 2610-2652,2731-2736,2797-2804,3057-3064 | 65 سطر / 7.15 كيلوبايت | عالٍ | loadContext وinit/login وselectRole وrenderShell. شرط الإبقاء صريح. CSS تسجيل الدخول مشترك. |
| ROLE_LABELS واختيار الدور | 2706,2792-2795,5962 | 6 سطر / 3.75 كيلوبايت | عالٍ | يستعملها مدير الحسابات عند 2706، والتدقيق عند 4249/4252/9449، والتقارير عند 4847، ومركز التحكم عند 14614/14777/14917–14923/15260/15365/15397. فرع teacher داخل وصف خيار الدخول منفصل فقط. |
| NAV والمساعدة والشاشة العامة وتهيئة التبويبات | 2508,3050,3061-3064,6182-6183,8711,11058,13690-13696 | 17 سطر / 6.79 كيلوبايت | عالٍ | NAV.teacher مرجع احتياطي للمساعدة وrenderShell. حساب المدرسة تُعاد كتابة قائمته في v293. تفصيل قرار حذف المفتاحين في ج. |
| mySchool وmyTeacherRecord ومفاتيح teacher:self | 3196-3202,3237,3480-3488,3672,3770 | 19 سطر / 1.62 كيلوبايت | متوسط | mySchool مشتركة. myTeacherRecord تُستدعى عند 3199 و4175 فقط، لكن تعريفها يعتمد على قرار الفرع العام ومناداة حصصي؛ مفاتيح الإبطال ضمن عمليات مشتركة. |
| المعلمون وTEACHER_ACTION_ROLES | 3533-3577,3588-3601,7167,11462-11467 | 66 سطر / 14.35 كيلوبايت | عالٍ | أدوار المدير والمنسق والموجه تستخدم الإدارة والانتداب وإيقاف الأجر والبحث. الفروع الخاصة تشمل الملكية والإضافة والاستكمال. لا حذف للصلاحيات المشتركة. |
| الاستكمال والتنبيهات | 2596,4190-4274,13416 | 87 سطر / 17.24 كيلوبايت | عالٍ | teacher هنا أيضًا نوع كيان بيانات. شروط الدورين ضمن المسار المشترك، وROLE_LABELS يستخدم في سجل المراجعة. |
| صفحة الموجهين ومحوّل تقريرها | 3972-3987,6431 | 17 سطر / 2.28 كيلوبايت | متوسط | فرع الاتصال يخدم school_manager أيضًا. قائمة الموجهين وبياناتهم للأدوار الإدارية تبقى. |
| تعديل الإسناد والفصول والاعتماد | 4122,4593-4640,7024,8180-8189,9283 | 61 سطر / 10.71 كيلوبايت | عالٍ | assignmentEditCanManage يشمل المدير، وv281 والفصول والاعتماد تستعملها أدوار عاملة. فرع إرسال المدرسة وحده في أ. |
| فلاتر المرحلة والمدرسة وقواعد نطاق التقارير | 7629,8097,8170-8190,8245-8293,8393-8394,8428,9914,11688 | 77 سطر / 6.53 كيلوبايت | عالٍ | v86/v97/v98/v115/v163/v179/v278/v233 مشتركة. إزالة شرط الدور ليست مبررًا لحذف الوظيفة أو الفرع الذي يحتوي school_manager. |
| الجداول الأسبوعية والإنجاز وطباعة المدرسة | 8600-8610,8711-8717,13784-13787,13872-13952 | 103 سطر / 11.63 كيلوبايت | عالٍ | v101 وv102 وv306 مشتركة. __v161EmbedTimetable وحده خاص بتضمين حصصي. |
| ملخص المدرسة v124 وCSS الجداول | 10062-10103,1531-1532,5339,5563,7058 | 47 سطر / 9.18 كيلوبايت | عالٍ | v124SchoolBoard للدور school_manager أيضًا. v124Kpi مستخدمة عند 10424 و10444 و13872. CSS v118-plain-table مستخدم للفصول حسب الصف عند 10002. |
| v293 لوحة مسؤول البيانات والأغلفة المشتركة | 13689,13702,13722-13783 | 64 سطر / 8.19 كيلوبايت | عالٍ | غلاف loadPage عند 13729 يستدعي v293SupPanel للمدير والمنسق والموجه. v293OfficerText والتعيين وزر إنشاء الحساب والشارات تبقى. لا يُمس مشغّل قاعدة البيانات. |
| مركز التحكم وسجل الحسابات ومصفوفة صلاحيات الواجهة | 14614,14723,14889-14924,15096-15131,15180,15260-15262,15365,15397 | 80 سطر / 10.10 كيلوبايت | عالٍ | V356/V357 أدوات يستخدمها المدير. V360_FUNCS يبني أغلفة وقاعدة مطابقة من أسماء الدوال، ومنها submitSchool وإضافة معلم. لا يُحذف القاموس. |
| إنشاء الحساب والبحث بالهوية | 2706-2715,6945,6960,6970-6989,13775-13781,14221-14245 | 64 سطر / 17.75 كيلوبايت | عالٍ | أسماء الدورين هنا قد تكون الدور المستهدف أو نوع طلب RPC. teacher-only في النموذج يصف الحساب المنشود، ويُستبقى لمسارات المدير والموجه. |
| تعديل بيانات المعلم v344/v421/v440 | 14277-14278,16915-16943,17155-17167 | 44 سطر / 3.40 كيلوبايت | عالٍ | V344_ROLES وV421_ROLES ومحدد senior داخل v440 جزء من شاشة يستخدمها المدير والمنسق والموجه. |
| مفاتيح البوابة وصحائف الأحوال | 15477-15582,15944,15996-15997,16373-16375 | 112 سطر / 13.96 كيلوبايت | عالٍ | teacher هنا طرف البوابة أو رافع الصحيفة، وشاشة التحكم للمدير والمنسق. |
| قوالب طباعة ومشاركة المعلم والموجه | 16965-17145,3564-3569,5709 | 188 سطر / 16.22 كيلوبايت | عالٍ | أزرار الأدوار النشطة تمرر teacherId إلى v435Print. v438 مشتركة أيضًا مع صحيفة الموجه. الفرع القديم بلا معرّف هو وحده موضع قرار. |
| CSS البطاقات والبحث الموحد | 29-42,1479,1520-1522,9195,11719 | 20 سطر / 1.91 كيلوبايت | متوسط | v110-facts عام، وكذلك v233CanUse؛ استثناء المعلم لا يجعل ميزة البحث خاصة به. |

## ج — مواضع تحتاج قرارًا

| العنصر | أسطر index.html | القياس التقريبي | خطر الحذف | المراجع وحدود النطاق |
|---|---|---:|---|---|
| مفتاحا NAV.teacher وNAV.senior_teacher | 3050,3061,6182-6183,11058,13690-13696 | 12 سطر / 2.55 كيلوبايت | عالٍ | حذف الأول يقطع fallback المشترك، والثاني تعيد بناءه أغلفة v293 في كل جلسة. يُستبقيان دون موافقة على تسوية المراجع. |
| ReportAdapters.teacherSelf واستثناءاته | 7613-7617,13222,15590 | 7 سطر / 1.03 كيلوبايت | متوسط | الزر المباشر عند 7611 خاص بالمعلم، لكن المحوّل في سجل عام، ومعرّفه مستثنى في V256 وV374_KEEP. أدرج قرار المحوّل مع صفحة v160 حتى لا تنكسر تبعياتها. |
| V160_TEACHER_FIELDS وv160LoadSelf والطباعة دون معرّف | 7581,7584-7593,16965-16980,17114-17117 | 31 سطر / 2.75 كيلوبايت | عالٍ | تُستدعى من v160 ومن v437Load عند teacherId==null. الأزرار الحالية للأدوار العاملة تمرر ID. استدعاء عام دون ID ما زال جزءًا من الدالة؛ لا حذف دون موافقة. |
| فصل أغلفة v293 العامة عن جهة حساب المدرسة | 13722-13729 | 8 سطر / 0.93 كيلوبايت | عالٍ | تبقى لوحة المسؤول عبر 13729. إزالة دوال القسم الخاص أو CSS أو مستمعه تحتاج خريطة تغييرات مقترنة بالأغلفة قبل التنفيذ. |
| حذف أسماء الدورين من مركز التحكم أو السجل | 5962,14723,14889-14896,15180 | 11 سطر / 1.74 كيلوبايت | عالٍ | يؤثر في نص المدير أو عدد الأزرار وقد يؤثر في عرض السجلات والاستثناءات. القفل لا يحسم ذلك. |

## فهرس مراجع الأسماء

| الاسم | جميع أسطر التطابق النصي في index.html |
|---|---|
| myAssignments | 2834, 3076, 5822, 6183, 6339, 8097, 13966 |
| myAssignmentsPage | 3076, 4174, 11065, 11066 |
| myTeacherRecord | 3199, 3480, 4175 |
| teacherSelf | 7585, 7611, 7613, 7616, 13222, 15590 |
| v160Date | 7582, 7602 |
| v160Val | 7583, 7597, 7610, 7615, 7616 |
| v160LoadSelf | 7584, 7607, 7614, 16968 |
| v160Sections | 7594, 7610, 7615 |
| v160TeacherSelfPage | 7606, 7619, 11062 |
| V160_TEACHER_FIELDS | 7581, 7587 |
| __v160BaseTeachersPage | 7618, 7619 |
| __v161BaseDashboard | 11059, 11061 |
| __v161BaseMyAssignments | 11065, 11067 |
| __v161EmbedTimetable | 8610, 11068 |
| seniorTeacherAddTeacherForm | 2014, 2506, 3577, 5821, 6964, 13691, 15098 |
| fastTeacherForm | 6966, 6967 |
| createSchoolTeacher | 6966, 6989 |
| uxCreateTeacherSequence | 6974, 6980, 6989 |
| submitSchool | 2014, 4625, 4632, 7087, 13691, 15103 |
| __uxSubmitSchool | 7087 |
| supervisor-tools-card | 1173, 1180, 1241, 2506 |
| supervisor-tools-grid | 1174, 1224, 2506, 5829 |
| supervisor-tool-btn | 1175, 1176, 1177, 1178, 1179, 1229, 1239, 1240, 1305, 1412, 2506 |
| v339-mypw | 14271 |
| __v339BaseDashboard | 14267, 14269 |
| v270ChangePassword | 3912, 3944, 14271 |
| NAV.teacher | 3050, 3061, 11058 |
| NAV.senior_teacher | 13690, 13695 |
| ROLE_LABELS | 2706, 2792, 2793, 3050, 3064, 3577, 4249, 4252, 4847, 5962, 9449, 14614, 14777, 14791, 14917, 14919, 14923, 15260, 15365, 15397 |
| V307_ORDER | 13956, 13969, 14050, 14719, 15997, 16375 |
| TEACHER_ACTION_ROLES | 3533, 3553, 3571, 3572, 11462, 11465, 11466 |
| V293_NAV_BASE | 13690, 13695 |
| V293_EDIT_RE | 13691, 13720 |
| v293Info | 13689, 13692, 13699, 13700, 13703, 13708, 13713, 13723, 13725 |
| v293Sup | 13689, 13736, 13737, 13747, 13760, 13765, 13766, 13771, 13776, 13778 |
| v293ApplyNav | 13693, 13723, 13725, 13727 |
| v293Load | 13698, 13723, 13725 |
| v293ReadOnly | 13692, 13694, 13706, 13715, 13725 |
| v293OfficerText | 13702, 13708, 13741 |
| v293Msg | 13703, 13720 |
| v293Banner | 13704, 13729 |
| v293Chip | 13711, 13725, 13727 |
| v293SupPanel | 13729, 13731, 13768, 13781 |
| v293DecorateRows | 13744, 13746 |
| v293SetOfficer | 13741, 13754, 13759, 15107 |
| v293DoSet | 13762, 13764 |
| v293CreateAccount | 13741, 13755, 13770, 15108 |
| v293DoCreate | 13773, 13775, 15108 |
| __v293BaseLoadContext | 13722, 13723 |
| __v293BaseSelectRole | 13724, 13725 |
| __v293BaseRenderShell | 13726, 13727 |
| __v293BaseLoadPage | 13728, 13729 |
| v124SchoolBoard | 10064, 10100 |
| v124Kpi | 10062, 10091, 10424, 10444, 13872 |
| v124OpenTimetable | 10063, 10085 |
| V344_ROLES | 14277, 14278 |
| V421_ROLES | 16915, 16917, 16943, 17167 |
| V356_ROLES | 14723, 14777 |
| V357_ROLES | 14889, 14905, 14915, 14917, 14918, 14919, 15260, 15262, 15397 |
| V360_FUNCS | 15097, 15110 |
| v437Load | 16965, 17115 |
| v435Print | 3564, 3569, 5709, 17114, 17144 |
| v446LockedRole | 2618, 2640, 2798, 3059 |
| v446PortalScreen | 2621, 2643, 2798, 3059 |

## فهرس المواضع التي تذكر الدورين نصيًا

يتضمن التطابق أيضًا أنواع الكيانات وأعمدة التقارير وأدوار الحسابات المستهدفة. ليس كل تطابق مرشحًا للحذف.

- 2506 — t seniorActions=profile.role==='senior_teacher'?<div class="card super
- 2507 — ervisorRoleHint=profile.role==='teacher'&&userRoles.includes('se، ='teacher'&&userRoles.includes('senior_teacher')?<div class="notice in، start:8px" onclick="selectRole('senior_teacher')">الدخول كمشرف المادة</
- 2596 — (!el¦¦!profile¦¦profile.role==='teacher')return;
- 2619 — return role==='teacher'¦¦role==='senior_teacher، eturn role==='teacher'¦¦role==='senior_teacher';
- 2711 — le.role==='supervisor')roles=[['senior_teacher','أقدم معلم'],['teacher'، 'senior_teacher','أقدم معلم'],['teacher','معلم']];if(profile.rol، er','معلم']];if(profile.role==='senior_teacher')roles=[['teacher','معلم، ole==='senior_teacher')roles=[['teacher','معلم']];
- 2715 — ').forEach(x=>x.style.display=['senior_teacher','teacher'].includes(rol، tyle.display=['senior_teacher','teacher'].includes(role)?'block'، tyle.display=['school_manager','senior_teacher','teacher'].includes(rol، hool_manager','senior_teacher','teacher'].includes(role)?'block'
- 2793 — n">${role==='admin'?'⚙':role==='teacher'?'◉':'◆'}</span><span><b، والصلاحيات والإعدادات':role==='teacher'?'بياناتك المهنية والحصص
- 3064 — ><div><strong>${profile.role==='senior_teacher'?(profile.school_name¦¦'، ''}>⬇</button>${profile.role!=='teacher'?<button class="alert-b، يد">؟</button>${profile.role!=='teacher'?<button class="alert-b
- 3199 — if(['senior_teacher','teacher'].includes(pro، if(['senior_teacher','teacher'].includes(profile.role)
- 3237 — :(['school_manager','senior_teacher','teacher'].includes(pro، hool_manager','senior_teacher','teacher'].includes(profile.role)
- 3481 — return cachedRead(teacher:self:${selectFields},as
- 3533 — tage_coordinator','supervisor','senior_teacher'],delegate:['admin','sta، tage_coordinator','supervisor','senior_teacher'],cancelDelegation:['adm، tage_coordinator','supervisor','senior_teacher'],stopPaid:['admin','sta
- 3536 — const schoolScopedRole=['senior_teacher','school_manager','super
- 3553 — const canAdd=['supervisor','senior_teacher'].includes(profile.role)
- 3566 — onst ownTeacher=profile.role!=='senior_teacher'¦¦t.is_home_school!==fal
- 3577 — ?'معلمو مدارسي':profile.role==='teacher'?'بيانات المعلم':(['scho، نات المعلم':(['school_manager','senior_teacher'].includes(profile.role)، ary" onclick="${profile.role==='senior_teacher'?'seniorTeacherAddTeache
- 3588 — if(profile.role==='senior_teacher'){
- 3614 — pletion_change',{p_entity_type:'teacher',p_entity_id:id,p_field_
- 3623 — ,'assignments','page:reports','teacher:self','school:self']}).c
- 3672 — ,'page:reports','school:self','teacher:self');
- 3770 — ,'page:reports','school:self','teacher:self');
- 3980 — }else if(['school_manager','senior_teacher','teacher'].includes(pro، hool_manager','senior_teacher','teacher'].includes(profile.role)
- 4122 — ditCanManage(){return ['admin','senior_teacher'].includes(profile?.role
- 4191 — teacher:[['phone','رقم الهاتف'],
- 4195 — ,'phone','manager_profile_id'],teacher:['phone'],supervisor:['p
- 4197 — []).includes(field)¦¦(entity==='teacher'&&rec?.work_type==='paid
- 4218 — ata.teachers)rows.push({entity:'teacher',id:t.id,name:t.full_nam
- 4269 — ,'supervisor','school_manager','senior_teacher'].includes(profile?.role
- 4619 — if(profile.role==='senior_teacher'){
- 5265 — e==='teachers'&&profile.role==='senior_teacher'&&h==='المدرسة')return;
- 5821 — senior_teacher:[make('إضافة معلم','＋',(
- 5822 — teacher:[make('حصصي','Σ',()=>go(
- 5962 — ,school_manager:'مدير المدرسة',senior_teacher:'حساب المدرسة',teacher:'، ,senior_teacher:'حساب المدرسة',teacher:'المعلم'};
- 6182 — senior_teacher:[['dashboard','لوحة مشرف
- 6183 — teacher:[['dashboard','بياناتي',
- 6420 — hoolId:String(c.school_id¦¦''),teacher:reportCellValue(tmap[a.t
- 6421 — ods,0))],columns:[reportColumn('teacher','المعلم',1.6),reportCol
- 6431 — me');else if(['school_manager','senior_teacher','teacher'].includes(pro، hool_manager','senior_teacher','teacher'].includes(profile.role)
- 6900 — })],distribution:[reportColumn('teacher','المعلم',1.5),reportCol
- 6904 — (4)، ${longArabic},periods:0,teacher:'محمود عبدالمفدي محمد أب
- 6906 — r)r.name=${r.name} ${i+1};if('teacher' in r)r.teacher=${r.tea
- 6945 — ';let linkable=false;if(mode==='teacher')linkable=!!data.teacher
- 6958 — ctor('#modal form'),{draftKey:teacher:edit:${id}}))};
- 6960 — ew:${profile.role},civilMode:['teacher','senior_teacher'].inclu، le.role},civilMode:['teacher','senior_teacher'].includes(role)?'teache، enior_teacher'].includes(role)?'teacher':['supervisor','stage_co، ataset.civilLookup='';const m=['teacher','senior_teacher'].inclu
- 6967 — uxSmartifyForm(form,{draftKey:teacher:new:${s.id},civilMode:'، teacher:new:${s.id},civilMode:'teacher',schoolId:s.id});form.da
- 6975 — uxSmartifyForm(form,{draftKey:teacher:new:supervisor:${profile
- 6976 — ;uxInitCivilLookup(civil,{mode:'teacher',schoolId:()=>form.eleme
- 6981 — chool_id;Object.assign(f,{role:'teacher',school_id:schoolId});
- 6982 — ');uxIdentityHint(input,lookup,'teacher',schoolId);uxValidateFie
- 7024 — ;uxShowUndo(${profile?.role==='senior_teacher'?'تم إنشاء واعتماد':'تم
- 7167 — tage_coordinator','supervisor','senior_teacher'].includes(profile?.role
- 7619 — ons={}){return profile?.role==='teacher'?v160TeacherSelfPage(opt
- 7629 — return ['senior_teacher','school_manager','super
- 8180 — ='schools'&&(['school_manager','senior_teacher'].includes(profile?.role
- 8185 — ='approval'&&['school_manager','senior_teacher'].includes(profile?.role
- 8188 — ['supervisor','school_manager','senior_teacher'].includes(profile?.role
- 8201 — :new Set(schools.map(s=>s.id)),teacher:new Set(teachers.map(t=>
- 8245 — ='teachers'&&['school_manager','senior_teacher'].includes(profile?.role
- 8262 — else if(['school_manager','senior_teacher'].includes(role)){
- 8275 — ['supervisor','school_manager','senior_teacher'].includes(role)&&!(role
- 8291 — ='teachers'&&['school_manager','senior_teacher'].includes(profile?.role
- 8393 — &!!profile&&!['school_manager','senior_teacher','teacher'].includes(pro، hool_manager','senior_teacher','teacher'].includes(profile.role)
- 8394 — &!!profile&&!['school_manager','senior_teacher','teacher'].includes(pro، hool_manager','senior_teacher','teacher'].includes(profile.role)
- 8428 — rs'&&!!profile&&profile.role!=='teacher'}
- 8711 — ush(['teacherTimetable',role==='teacher'?'جدولي الأسبوعي':'جدول
- 8717 — 02_SCHOOL_PRINT_ROLES=new Set(['senior_teacher','school_manager','super
- 8739 — 'day','اليوم',.6),reportColumn('teacher','المعلم',2.3)];
- 8744 — 101_DAY_NAMES[day],_dk:'e'+day,teacher:'لا توجد حصص مسجلة'};for
- 8746 — 101_DAY_NAMES[day],_dk:'d'+day,teacher:t.full_name¦¦'—'};
- 9283 — t.v281Sup,canCls=['supervisor','senior_teacher'].includes(profile?.role
- 9747 — ame¦¦'معلم غير ظاهر في الكادر',teacher:teacher¦¦null,assignment
- 9914 — v115SingleSchoolRole(){return ['senior_teacher','school_manager','teach، nior_teacher','school_manager','teacher'].includes(profile?.role
- 10099 — if(!['senior_teacher','school_manager'].inclu
- 10272 — 0)continue;offers.push({from:r,teacher:x.d.teacher,rec:x.rec,am
- 10281 — sals.push({to:r,from:pick.from,teacher:pick.teacher,rec:pick.re
- 10315 — 3,{numeric:true}),reportColumn('teacher','المعلم المقترح',1.8),r، oposals.map((p,i)=>({index:i+1,teacher:p.teacher.full_name¦¦p.r
- 11061 — rd(options);if(profile?.role!=='teacher')return base;
- 11067 — ts(options);if(profile?.role!=='teacher')return base;
- 11464 — const r=profile?.role,own=r!=='senior_teacher'¦¦(!!it.schoolId&&!!v233
- 11485 — kload_status¦¦'');return {type:'teacher',id,name:t.full_name¦¦''
- 11539 — groups.push(['teacher','المعلمون',ix.teachers.
- 11544 — groups.push(['teacher','المعلمون',ix.teachers.
- 11563 — 'school','المدارس — '+lbl,sc],['teacher','المعلمون — '+lbl,tc]);
- 11569 — ','المدارس',rank(ix.schools)],['teacher','المعلمون',rank(ix.teac
- 11576 — if(it.type==='teacher'){
- 11586 — if(it.type==='teacher'){
- 11598 — if(it.type==='teacher'){const P=v233TeacherPer
- 11602 — const V233_ICON={school:'🏫',teacher:'👨‍🏫',sup:'🧭'};
- 11644 — if(x.type==='teacher')return ix?.teachers.fin
- 11666 — if(it.type==='teacher'){
- 11688 — page),multi=!['school_manager','senior_teacher'].includes(profile?.role
- 11719 — turn !!profile&&profile.role!=='teacher'&&!!document.querySelect
- 13416 — (!el¦¦!profile¦¦profile.role==='teacher')return;
- 13692 — dOnly(){return profile?.role==='senior_teacher'&&!!v293Info&&v293Info.i
- 13699 — 93Info=null;if(profile?.role!=='senior_teacher')return;
- 13713 — if(profile?.role!=='senior_teacher'¦¦!v293Info)return;
- 13725 — ply(this,a);if(profile?.role==='senior_teacher'){await v293Load();v293A
- 13778 — body={role:t.is_senior_teacher?'senior_teacher':'teacher',civil_id:Stri، enior_teacher?'senior_teacher':'teacher',civil_id:String(t.civil
- 13786 — ,'supervisor','school_manager','senior_teacher'],V306_ST=['مكتمل','ناقص
- 13946 — {index:0,school:r.school_name,teacher:r.teacher_name+(r.work_t
- 13949 — ue}),C('school','المدرسة',2),C('teacher','المعلم',2),C('required
- 13965 — senior_teacher:['dashboard','alerts','a
- 13966 — teacher:['dashboard','myAssignme
- 14173 — .select('id').eq('entity_type','teacher').eq('entity_id',id).eq(
- 14221 — civil_id¦¦'')}</b></span>${act('teacher')?'<span class="badge in، ge info">معلم</span>':''}${act('senior_teacher')?'<span class="badge in
- 14243 — const body={role:'teacher',civil_id:String(t.civil
- 14270 — if(profile?.role!=='teacher')return base;
- 14277 — tage_coordinator','supervisor','senior_teacher'];
- 14723 — supervisor','first_supervisor','teacher','school_manager'];
- 14889 — ,'supervisor','school_manager','teacher','first_supervisor'];/*
- 14893 — teacher:{all:'المعلم يرى بياناته
- 14895 — senior_teacher:{caps:{'school.settings'
- 15180 — c=m.querySelector('[data-role="teacher"]');if(c&&!c.checked){c.
- 15480 — const V433_ROLE={teacher:'المعلم',supervisor:'الم
- 15498 — return role==='teacher'?{t:t,s:0}:role==='super
- 15533 — const who=party==='teacher'?'رفع المعلم (البوابة)':
- 15562 — sub">المعلم</span>${tg(s.stage,'teacher',!!s.teacher_open)}<span
- 15944 — ${adm?row('teacher','رفع المعلم (البوابة)',
- 16703 — nst __v410={stage:'',school:'',teacher:'',from:'',to:'',html:''
- 16719 — v410Teacher" onchange="v410Set('teacher',this.value)">${opt('','
- 16829 — '',school:t.home_school_id¦¦'',teacher:id,from:'',to:'',html:''
- 16915 — tage_coordinator','supervisor','senior_teacher'];
- 17155 — S.includes(role),senior=role==='senior_teacher';
- 17198 — ctor('#modal form'),{draftKey:teacher:edit:${id}});


## نتيجة المرحلة الثانية

### ما اختُبر وما حُذف

- لوحة إدارة القسم وتلميح التبديل وقواعد CSS المخصصة لها — حُذف بعد تطابق المقارنة.
- إجراءات الهاتف الافتراضية للدورين من mobileDefaultActions — حُذف بعد تطابق المقارنة.
- مدخلا ترتيب الدورين في V307_ORDER — حُذف بعد تطابق المقارنة.
- غلاف كلمة مرور المعلم الخاص في v339 — حُذف بعد تطابق المقارنة.

### ما بقي

- بقيت صفحة «حصصي وفصولي» ومراجعها لأن NAV.teacher بقي بموجب القرار. بقيت أجزاء ملف v160 المرتبطة بمحوّل teacherSelf، وبقيت طباعة صحيفة المعلم بلا معرّف.
- بقيت إضافة المعلم السريعة وإرسال المدرسة للاعتماد لأن أسماءها واردة في قوالب أو أغلفة أو قواميس مشتركة محمية بالقرار، ومنها V293_EDIT_RE وV360_FUNCS.
- بقيت واجهة v293 المخصصة لحساب المدرسة حيث يعتمد عليها غلاف مشترك مترابط مع لوحة مسؤول البيانات للأدوار العاملة.
- بقيت مفاتيح NAV وROLE_LABELS وTEACHER_ACTION_ROLES والمحوّل teacherSelf والأغلفة المشتركة وشاشة القفل في v446.

### القياس والاختبارات

- قبل، 1,904.289 كيلوبايت عاديًا و573.811 كيلوبايت بـ gzip. بعد، 1,899.274 كيلوبايت عاديًا و572.923 كيلوبايت بـ gzip.
- لكل دفعة، فُحص السكربت بـ node --check وESLint no-undef، وقورنت النصوص وأعداد الأزرار في Playwright ببيانات وهمية عند 390 و1400 بكسل. انتظر الاختبار اكتمال تجهيز التقرير لمقارنة نفس الحالة المرئية. اللقطات الأولية الملتقطة أثناء التجهيز أُعيدت بعد تصحيح انتظار الاختبار.
- في v446 أصلًا 86 إشارة no-undef موزّعة على 25 اسمًا. المقارنة تمنع إضافة أي إشارة جديدة. بقي إصلاح الإشارات السابقة خارج نطاق الحذف.
- فُتحت تقارير ملخص الخطة، وأنصبة المعلمين، وبيانات معلمي المدارس من البطاقات وأزرار المعاينة. المسارات غير الممنوحة حسب القائمة الفعلية قورنت كحالة غير متاحة. لم تُرفع صلاحية أي دور في الاختبار.

| الدور | الصفحات والحالات المقارنة عند كل عرض، بما فيها القائمة والتقارير | Console |
|---|---:|---|
| admin | 14 | بلا أخطاء أو تحذيرات |
| stage_coordinator | 13 | بلا أخطاء أو تحذيرات |
| supervisor | 14 | بلا أخطاء أو تحذيرات |
| first_supervisor | 10 | بلا أخطاء أو تحذيرات |

### الأمان والنطاق

- لم تتغير بيانات الاعتماد أو صلاحيات القراءة أو الكتابة. بقيت شاشة v446 كما هي. لم يتغير index.html المنشور أو قاعدة البيانات أو دوالها أو سياساتها أو عروضها أو دوال الحافة، ولا بوابة المعلمين أو /coordinator/. لم يُشغّل get_advisors لأن قاعدة البيانات لم تتغير.
- لم تُختبر حسابات حقيقية. التحقق يقتصر على البيانات الوهمية ومسارات الواجهة المتاحة لكل دور.
