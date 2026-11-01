#!/usr/bin/env bash
# Copy the built iPhone version (web/app) to the gh-pages branch of this repo, which GitHub Pages
# serves at https://reha-abbasi.github.io/tempo-drift/. Run tools/make_phone.py first.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
git clone -q --depth 1 -b gh-pages https://github.com/reha-abbasi/tempo-drift.git "$tmp"
# (the Godot version lives in godot/, published by tools/publish_godot_web.sh: leave it alone)
find "$tmp" -mindepth 1 -maxdepth 1 ! -name .git ! -name README.md ! -name .nojekyll ! -name godot -exec rm -rf {} +
cp "$here"/web/app/index.html "$here"/web/app/manifest.webmanifest "$here"/web/app/sw.js "$here"/web/app/icon-{180,192,512}.png "$tmp"/
# a new service-worker version so phones fetch the update
sed -i "s/const VERSION='tempo-drift-[^']*'/const VERSION='tempo-drift-$(date +%Y%m%d%H%M%S)'/" "$tmp/sw.js"
cd "$tmp"
git add -A
if git diff --cached --quiet; then echo "Nothing changed."; exit 0; fi
git commit -q -m "Update the phone version"
git push -q
echo "Published. Live at https://reha-abbasi.github.io/tempo-drift/ in about a minute."
