const VERSION='tempo-drift-20261025034803';
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(VERSION).then(c=>c.addAll(['./','index.html','manifest.webmanifest','icon-180.png'])));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==VERSION).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;
  const page=r.mode==='navigate'||new URL(r.url).origin===location.origin;
  e.respondWith(page
    ? fetch(r).then(res=>{const c=res.clone();caches.open(VERSION).then(k=>k.put(r,c));return res;}).catch(()=>caches.match(r).then(m=>m||caches.match('index.html')))
    : caches.match(r).then(m=>m||fetch(r).then(res=>{const c=res.clone();caches.open(VERSION).then(k=>k.put(r,c));return res;})));});
