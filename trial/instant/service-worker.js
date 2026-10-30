// v230: فتح فوري — صفحة البرنامج تُعرض فورًا من نسخة محفوظة على الجهاز، وتُحدَّث النسخة في الخلفية عند كل فتح
// (والبرنامج نفسه يتحقق بعد التحميل فيُظهر شريط «نسخة جديدة» إن نُشر إصدار أحدث).
// تُخزَّن صفحة البرنامج فقط (طلبات التنقل داخل نطاق العامل)؛ البيانات وكل ما عداها من الشبكة مباشرة كما كان.
const SHELL='sg-shell-v1';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil((async()=>{for(const k of await caches.keys())if(k!==SHELL)await caches.delete(k);await self.clients.claim()})()));
self.addEventListener('fetch',e=>{
  const req=e.request;
  if(req.method!=='GET'||req.mode!=='navigate')return;
  const url=new URL(req.url);
  if(url.origin!==self.location.origin)return;
  const key=url.origin+url.pathname;
  e.respondWith((async()=>{
    const cache=await caches.open(SHELL),cached=await cache.match(key);
    const net=fetch(req,{cache:'no-cache'}).then(async res=>{
      if(res&&res.ok&&res.type==='basic'&&(res.headers.get('content-type')||'').includes('text/html'))await cache.put(key,res.clone());
      return res;
    });
    if(cached){e.waitUntil(net.catch(()=>{}));return cached}
    try{return await net}catch(err){return Response.error()}
  })());
});
