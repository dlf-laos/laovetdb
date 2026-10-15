const CACHE='lvsp-shell-release-20261016';
const SHELL=['/','/index.html','/manifest.webmanifest','/icons/icon-192.png','/icons/icon-512.png'];

self.addEventListener('install',event=>{
  event.waitUntil(
    caches.open(CACHE)
      .then(c=>c.addAll(SHELL))
      .then(()=>self.skipWaiting())
  );
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(
        keys.filter(k=>k.startsWith('lvsp-shell-')&&k!==CACHE).map(k=>caches.delete(k))
      ))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('message',event=>{
  if(event.data?.type==='SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch',event=>{
  const req=event.request;
  if(req.method!=='GET') return;

  const url=new URL(req.url);
  if(url.origin!==location.origin) return;

  // Never cache authenticated API responses.
  if(url.pathname.startsWith('/api/')){
    event.respondWith(fetch(req));
    return;
  }

  // Field PWA has its own service worker.
  if(url.pathname.startsWith('/field/')) return;

  // Navigation is network-first, with offline fallback.
  if(req.mode==='navigate'){
    event.respondWith(
      fetch(req)
        .then(r=>{
          if(r.ok){
            const copy=r.clone();
            caches.open(CACHE).then(c=>c.put('/index.html',copy));
          }
          return r;
        })
        .catch(()=>caches.match('/index.html'))
    );
    return;
  }

  // Development-critical JS/CSS/modules are NETWORK-FIRST so a new build is visible immediately.
  if(url.pathname.endsWith('.js') || url.pathname.endsWith('.css')){
    event.respondWith(
      fetch(req)
        .then(r=>{
          if(r.ok){
            const copy=r.clone();
            caches.open(CACHE).then(c=>c.put(req,copy));
          }
          return r;
        })
        .catch(()=>caches.match(req))
    );
    return;
  }

  // Images/manifests/etc may remain cache-first.
  event.respondWith(
    caches.match(req).then(cached=>
      cached || fetch(req).then(r=>{
        if(r.ok){
          const copy=r.clone();
          caches.open(CACHE).then(c=>c.put(req,copy));
        }
        return r;
      })
    )
  );
});
