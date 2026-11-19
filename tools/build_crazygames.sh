#!/usr/bin/env bash
# Build the (single) Web export and zip it for CrazyGames. The same build runs on GitHub Pages: the CrazyGames
# SDK in its HTML head detects where it runs (crazygames / local / disabled) and the game adapts at runtime.
# Usage (Git Bash, from the project root):  bash tools/build_crazygames.sh
#   -> build/web/ (test on localhost) and build/IronRedoubt-crazygames.zip (upload this to CrazyGames)
set -euo pipefail
GODOT="${GODOT:-C:/code/godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf build/web build/crazygames build/IronRedoubt-crazygames.zip
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1 || true
if [ ! -f build/web/index.wasm ] || ! grep -q "crazygames-sdk-v3" build/web/index.html; then
	echo "Export failed or SDK script missing" >&2
	exit 1
fi
rm -f build/web/*.import
python - <<'PY'
import os, zipfile
src = "build/web"
with zipfile.ZipFile("build/IronRedoubt-crazygames.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(os.listdir(src)):
        z.write(os.path.join(src, f), f)
print("zip:", os.path.getsize("build/IronRedoubt-crazygames.zip") // 1024, "KB")
PY
echo "== Done: build/IronRedoubt-crazygames.zip"
