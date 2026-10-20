"""Turn Godot's web export into a page that can be published as a Claude artifact:
split the wasm into <15MB parts and stitch them back together in the browser with a fetch shim.
Usage: python3 tools/web_artifact.py export/web OUT_DIR   (tools/web_preview.sh runs this for you)"""
import re, sys, json
from pathlib import Path
src, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
for f in out.iterdir(): f.unlink()
wasm = (src / "index.wasm").read_bytes()
CH = 13_500_000
parts = []
for i in range(0, len(wasm), CH):
    name = f"index.part{len(parts)}.wasm"
    (out / name).write_bytes(wasm[i:i + CH]); parts.append(name)
(out / "index.pck.wasm").write_bytes((src / "index.pck").read_bytes())
for f in ["index.js", "index.audio.worklet.js", "index.audio.position.worklet.js", "index.png", "index.icon.png"]:
    (out / f).write_bytes((src / f).read_bytes())
html = (src / "index.html").read_text()
style = re.search(r"<style>(.*?)</style>", html, re.S).group(1)
body = re.search(r"<body>(.*?)</body>", html, re.S).group(1)
style = style.replace("background-color: black;", "background-color: #0e1a2b;")
shim = """<script>
(function () {
  const PARTS = %s;
  const realFetch = window.fetch.bind(window);
  window.fetch = async function (input, init) {
    const url = typeof input === 'string' ? input : (input && input.url) || '';
    const name = url.split('?')[0].split('/').pop();
    if (name === 'index.wasm') {
      const bufs = await Promise.all(PARTS.map(function (p) {
        return realFetch(p).then(function (r) {
          if (!r.ok) throw new Error('Could not load game file ' + p + ' (' + r.status + ')');
          return r.arrayBuffer();
        });
      }));
      const blob = new Blob(bufs, { type: 'application/wasm' });
      return new Response(blob, { status: 200, headers: { 'Content-Type': 'application/wasm', 'Content-Length': String(blob.size) } });
    }
    if (name === 'index.pck') {
      // the host only serves known file types, so the game data ships as .wasm
      return realFetch('index.pck.wasm', init);
    }
    return realFetch(input, init);
  };
})();
</script>
""" % json.dumps(parts)
body = body.replace('<script src="index.js"></script>', shim + '<script src="index.js"></script>')
page = f"""<title>Lane Runner</title>
<meta name="color-scheme" content="dark">
<style>
:root {{ --bg: #0e1a2b; --fg: #ffffff; color-scheme: dark; }}
html, body {{ height: 100%; background: var(--bg); color: var(--fg); }}
{style}
</style>
{body}"""
(out / "index.html").write_text(page)
print(parts, len(page))
