"""download Freesound HQ previews (CC0 only, checked on each sound page): fs_get.py ID...  -> raw/ID.mp3 + meta.json"""
import json, re, sys, subprocess, time, os
meta = json.load(open('meta.json')) if os.path.exists('meta.json') else {}
for sid in sys.argv[1:]:
    if sid in meta:
        continue
    h = subprocess.run(['curl', '-sSL', '-A', 'Mozilla/5.0', f'https://freesound.org/s/{sid}/'], capture_output=True, text=True).stdout
    lic = 'Creative Commons 0' in h and 'creativecommons.org/publicdomain/zero' in h
    m = re.search(r'https://cdn\.freesound\.org/previews/\d+/' + sid + r'_\d+-hq\.mp3', h) or re.search(r'https://cdn\.freesound\.org/previews/\d+/' + sid + r'_\d+-lq\.mp3', h)
    t = re.search(r'<title>Freesound - ([^<]+)</title>', h)
    u = re.search(r'/people/([^/]+)/sounds/' + sid, h)
    if not (lic and m):
        print(sid, 'SKIP (licence not CC0 or no preview)'); continue
    url = m.group(0).replace('-lq.mp3', '-hq.mp3')
    subprocess.run(['curl', '-sSLf', '-o', f'raw/{sid}.mp3', url], check=True)
    meta[sid] = {'title': t.group(1) if t else '?', 'user': u.group(1) if u else '?', 'license': 'CC0', 'url': f'https://freesound.org/s/{sid}/'}
    print(sid, meta[sid]['title'][:70])
    time.sleep(0.7)
json.dump(meta, open('meta.json', 'w'), indent=1)
