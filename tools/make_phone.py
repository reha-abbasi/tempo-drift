#!/usr/bin/env python3
"""Build the iPhone version of Tempo Drift from the game page.

    python3 tools/make_phone.py web/game.html web/app

The game page (web/game.html) is the same page as the claude.ai preview: the game screen next to the notes.
The phone version shows only the game, full screen, and can be added to the iPhone home screen, where it
opens like an app (no Safari bars) with its own icon. It also keeps working offline after the first launch.
"""
import json, sys, pathlib

src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
page = src.read_text()
out.mkdir(parents=True, exist_ok=True)

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black">
<meta name="apple-mobile-web-app-title" content="Tempo Drift">
<meta name="theme-color" content="#000000">
<link rel="apple-touch-icon" href="icon-180.png">
<link rel="icon" href="icon-192.png">
<link rel="manifest" href="manifest.webmanifest">
"""

# only the game: the screen fills the phone between the status bar and the home bar; no page scrolling,
# no text selection or long-press menus while playing
CSS = """<style>
html,body{margin:0;height:100%;overflow:hidden;overscroll-behavior:none;background:#000;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent}
body{padding:0!important}
.wrap{display:block!important;max-width:none!important;margin:0!important;height:100%}
.info,.hint{display:none!important}
.stage{position:fixed;left:env(safe-area-inset-left);right:env(safe-area-inset-right);top:env(safe-area-inset-top);bottom:env(safe-area-inset-bottom);gap:0!important}
.screen{aspect-ratio:auto!important;width:100%;height:100%;max-width:none!important;border-radius:0!important;box-shadow:none!important}
</style>
"""

SW_REG = """<script>if('serviceWorker' in navigator)addEventListener('load',()=>navigator.serviceWorker.register('sw.js').catch(()=>{}));</script>
"""

assert page.lstrip().startswith('<title>'), 'expected the game page to start with its <title>'
i = page.index('</style>') + len('</style>')
app = HEAD + page[:i] + '\n' + CSS + '</head>\n<body>\n' + page[i:] + '\n' + SW_REG + '</body>\n</html>\n'
(out / 'index.html').write_text(app)

(out / 'manifest.webmanifest').write_text(json.dumps({
    'name': 'Tempo Drift', 'short_name': 'Tempo Drift', 'start_url': './', 'scope': './', 'display': 'fullscreen',
    'orientation': 'portrait', 'background_color': '#000000', 'theme_color': '#000000',
    'icons': [{'src': 'icon-192.png', 'sizes': '192x192', 'type': 'image/png'},
              {'src': 'icon-512.png', 'sizes': '512x512', 'type': 'image/png'}]}, indent=2))

# offline: the game page is fetched fresh when there is a connection; the 3D library and fonts are kept after
# the first launch. Bump VERSION to drop old copies.
(out / 'sw.js').write_text("""const VERSION='tempo-drift-1';
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(VERSION).then(c=>c.addAll(['./','index.html','manifest.webmanifest','icon-180.png'])));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==VERSION).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;
  const page=r.mode==='navigate'||new URL(r.url).origin===location.origin;
  e.respondWith(page
    ? fetch(r).then(res=>{const c=res.clone();caches.open(VERSION).then(k=>k.put(r,c));return res;}).catch(()=>caches.match(r).then(m=>m||caches.match('index.html')))
    : caches.match(r).then(m=>m||fetch(r).then(res=>{const c=res.clone();caches.open(VERSION).then(k=>k.put(r,c));return res;})));});
""")
print('wrote', out / 'index.html', f'({len(app)//1024} KB)')
