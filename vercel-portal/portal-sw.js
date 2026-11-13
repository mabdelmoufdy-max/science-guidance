/* v364: عامل خدمة بسيط لتثبيت بوابة المعلمين — لا يخزن شيئًا؛ كل الطلبات تذهب للشبكة كما هي */
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });
self.addEventListener('fetch', function () { /* بلا تدخل */ });
