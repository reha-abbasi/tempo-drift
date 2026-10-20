#!/usr/bin/env bash
# Export the Web preset and package it for the Claude artifact preview.
# Usage: tools/web_preview.sh [OUT_DIR] [GODOT_BIN]   (default OUT_DIR: build/web_artifact)
set -euo pipefail
OUT=${1:-build/web_artifact}
GODOT=${2:-${GODOT:-godot}}
cd "$(dirname "$0")/.."
mkdir -p export/web "$OUT"
# keep Godot from importing (and packing) earlier build output
touch export/.gdignore "$(dirname "$OUT")/.gdignore"
"$GODOT" --headless --path . --export-release "Web" export/web/index.html
python3 tools/web_artifact.py export/web "$OUT"
ls -la "$OUT"
