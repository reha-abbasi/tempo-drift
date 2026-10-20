#!/usr/bin/env bash
# Render screenshots of the menu, gameplay and game-over screen on a Linux box
# without a monitor (needs xvfb + mesa). Usage: tools/screenshots.sh OUT_DIR [GODOT_BIN]
set -euo pipefail
OUT=${1:?output dir}
GODOT=${2:-${GODOT:-godot}}
cd "$(dirname "$0")/.."
rm -rf "$OUT" && mkdir -p "$OUT/menu" "$OUT/play" "$OUT/over"
run() { WAYLAND_DISPLAY= xvfb-run -a -s "-screen 0 720x1280x24" "$GODOT" --display-driver x11 --audio-driver Dummy \
          --path . --resolution 720x1280 --fixed-fps 30 "$@" 2>&1 | grep -E "RUN|ERROR|SCRIPT" || true; }
run --quit-after 100 -- --shots="$OUT/menu"
run -- --autoplay --runs=1 --seed=5 --max-time=40 --shots="$OUT/play"
run -- --autoplay --no-bot --runs=1 --seed=3 --shots="$OUT/over"
ls "$OUT"/*
