"""search Freesound for CC0 sounds (public web search, no account): fs_search.py QUERY... -> results.json"""
import json, re, sys, time, urllib.parse, subprocess, html

def search(q, pages=1):
    out = []
    for page in range(1, pages + 1):
        url = 'https://freesound.org/search/?' + urllib.parse.urlencode({'q': q, 'f': 'license:"Creative Commons 0"', 's': 'Downloads', 'page': page})
        h = subprocess.run(['curl', '-sSL', '-A', 'Mozilla/5.0', url], capture_output=True, text=True).stdout
        # each result: a player with data-mp3 and a link to the sound page with its title
        for m in re.finditer(r'data-mp3="(https://cdn\.freesound\.org/previews/\d+/(\d+)_\d+-lq\.mp3)"', h):
            sid = m.group(2)
            seg = h[m.end():m.end() + 6000]
            t = re.search(r'href="(/people/[^/]+/sounds/' + sid + r'/)"[^>]*title="([^"]+)"', h)
            dur = re.search(r'data-duration="([\d.]+)"', h[m.start() - 600:m.end() + 600])
            out.append({'id': sid, 'q': q, 'title': html.unescape(t.group(2)) if t else '?', 'page': t.group(1) if t else '',
                        'hq': m.group(1).replace('-lq.mp3', '-hq.mp3'), 'dur': float(dur.group(1)) if dur else None})
        time.sleep(1.0)
    return out

if __name__ == '__main__':
    res = {}
    for q in sys.argv[1:]:
        for r in search(q):
            res.setdefault(r['id'], r)
    json.dump(list(res.values()), open('results.json', 'w'), indent=1)
    for r in res.values():
        print(f"{r['id']:>7} {str(r['dur'])[:5]:>6}s  [{r['q']}] {r['title'][:70]}")
