#!/usr/bin/env bash
# Build the (single) Web export and publish it to the `host-test` branch (GitHub Pages source).
# Same build as the CrazyGames upload; there the SDK is "disabled", so the game uses its own test ads.
# The branch holds ONLY the built files and is replaced on every run (force push).
# Usage (Git Bash, from the project root):  bash tools/deploy_web.sh
#   GODOT=<path to Godot console exe> to override the default below.
set -euo pipefail

GODOT="${GODOT:-C:/code/godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
BRANCH="host-test"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REMOTE="$(git remote get-url origin)"

echo "== Exporting Web build"
rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1 || true
if [ ! -f build/web/index.wasm ] || [ ! -f build/web/index.pck ]; then
	echo "Export failed: build/web is incomplete" >&2
	exit 1
fi
rm -f build/web/*.import

echo "== Publishing to $BRANCH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -r build/web/. "$TMP/"
touch "$TMP/.nojekyll" # serve files as-is (no Jekyll processing)
SHA="$(git rev-parse --short HEAD)"
(
	cd "$TMP"
	git init -q
	git checkout -q -b "$BRANCH"
	git add -A
	git commit -q -m "Web build from $SHA ($(date '+%Y-%m-%d %H:%M'))"
	git push -q -f "$REMOTE" "$BRANCH"
)
echo "== Done: $BRANCH updated from $SHA"
