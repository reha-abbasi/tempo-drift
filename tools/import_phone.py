#!/usr/bin/env python3
"""Bring changes made to the published iPhone version back into the game page.

    python3 tools/import_phone.py path/to/gh-pages-copy/index.html web/game.html

If someone edits index.html on the gh-pages branch directly, this turns that file back into
web/game.html (the inverse of make_phone.py), takes over any change to the phone-only styles, and checks
that rebuilding gives exactly the same file.
"""
import re, subprocess, sys, tempfile, pathlib

app_path, out = sys.argv[1], sys.argv[2]
maker = pathlib.Path(__file__).with_name('make_phone.py')
app = open(app_path).read()
mk = maker.read_text()
i = app.index('<title>'); h = app.index('</head>'); k = app.rfind('<style>', 0, h)
assert app[h:h + 15] == '</head>\n<body>\n' and app[k - 1] == '\n', 'not a page made by make_phone.py'
body = app[h + 15:]
sw = re.search(r'SW_REG = """(.*?)"""', mk, re.S).group(1)
tail = '\n' + sw + '</body>\n</html>\n'
assert body.endswith(tail), 'unexpected ending'
open(out, 'w').write(app[i:k - 1] + body[:-len(tail)])
# the phone-only styles live in make_phone.py
old = re.search(r'CSS = """(.*?)"""', mk, re.S).group(1)
if old != app[k:h]: maker.write_text(mk.replace(old, app[k:h], 1)); print('updated the phone styles in make_phone.py')
d = tempfile.mkdtemp(); subprocess.run([sys.executable, str(maker), out, d], check=True, capture_output=True)
print('wrote', out, '| rebuild identical:', open(d + '/index.html').read() == app)
