// v152: عامل خدمة بسيط لتمكين تثبيت التطبيق فقط. لا يخزّن الصفحة ولا البيانات؛ كل الطلبات من الشبكة مباشرة.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('fetch',()=>{});
