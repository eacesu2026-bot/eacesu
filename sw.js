/* Service worker — كاش خفيف للتشغيل كتطبيق (شبكة أولًا حتى تصل التحديثات فورًا) */
const CACHE = "ay-v2";
const ASSETS = ["./", "./index.html", "./logo-abu-younes.jpg", "./config.js", "./notify.js"];
self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS).catch(()=>{})).then(()=>self.skipWaiting()));
});
self.addEventListener("activate", e => e.waitUntil(
  caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(()=>self.clients.claim())
));
self.addEventListener("fetch", e => {
  const u = e.request.url;
  if (e.request.method !== "GET") return;
  if (u.includes("supabase") || u.includes("callmebot") || u.includes("wa.me")) return;
  // شبكة أولًا، والكاش عند انقطاع الاتصال فقط
  e.respondWith(
    fetch(e.request).then(res => {
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(e.request, copy)).catch(()=>{});
      return res;
    }).catch(() => caches.match(e.request))
  );
});
