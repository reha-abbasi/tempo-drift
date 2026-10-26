#!/usr/bin/env bash
# Export the Godot version for the web and publish it to the public project reha-abbasi/tempo-drift, in godot/,
# which GitHub Pages serves at https://reha-abbasi.github.io/tempo-drift/godot/ (it runs in Safari on iPhone).
# Needs Godot 4.7.2 (~/.local/bin/godot) and its web export templates.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d)"
# export from a copy, so the import cache of the Windows editor in godot/game/.godot isn't touched
src="$(mktemp -d)"
rsync -a --exclude .godot "$here/godot/game/" "$src/"
godot --headless --path "$src" --import > "$out.log" 2>&1 || true
godot --headless --path "$src" --export-release "Web" "$out/index.html" >> "$out.log" 2>&1 || { tail -20 "$out.log"; exit 1; }
ls -la "$out"
tmp="$(mktemp -d)"
git clone -q https://github.com/reha-abbasi/tempo-drift.git "$tmp"
rm -rf "$tmp/godot"
mkdir -p "$tmp/godot"
cp -r "$out"/* "$tmp/godot/"
cd "$tmp"
git add -A
if git diff --cached --quiet; then echo "Nothing changed."; exit 0; fi
git commit -q -m "Update the Godot version"
git push -q
echo "Published. Live at https://reha-abbasi.github.io/tempo-drift/godot/ in a minute or two."
