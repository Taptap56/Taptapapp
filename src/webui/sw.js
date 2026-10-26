// TaptapApp WebUI service worker — syarat agar WebUI bisa di-install
// sebagai aplikasi (PWA) dari Chrome, sekaligus bikin buka WebUI tetap
// cepat (aset statis di-cache, API selalu lewat network).
const CACHE = 'taptapapp-v1';
const CORE = [
  './', 'index.html', 'login.html', 'app.js', 'style.css', 'manifest.json',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/icon-maskable-512.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(CORE)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const u = new URL(e.request.url);
  if (u.pathname.indexOf('/api/') === 0) return; // API: selalu network, jangan di-cache
  // WebUI dilayani dari localhost (selalu online): utamakan network agar
  // update modul langsung terlihat; cache hanya fallback darurat.
  e.respondWith(
    fetch(e.request).then((res) => {
      // Jangan cache hasil redirect (mis. "/" -> "/login.html" saat belum
      // login): kalau di-cache, halaman login bisa muncul walau sudah login.
      if (res && res.ok && !res.redirected) {
        const cp = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, cp));
      }
      return res;
    }).catch(() => caches.match(e.request))
  );
});

self.addEventListener('message', (e) => {
  if (e.data === 'skip') self.skipWaiting();
});
