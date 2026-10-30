#!/bin/sh
# Freeze a built app folder as a candidate: an exact copy that is never
# rewritten, with SHA256SUMS and CANDIDATE.json beside it.
#
#   scripts/sw2-freeze.sh <built-app-dir> <candidate-dir>
#
# POSIX sh; runs on Linux and macOS.  Freeze on the machine that built the
# app, then copy the whole candidate folder to the machine with the console.
set -eu

usage() { echo "usage: $0 <built-app-dir> <candidate-dir>" >&2; exit 2; }
[ $# -eq 2 ] || usage
SRC=$1
DEST=$2
[ -d "$SRC" ] || { echo "sw2-freeze: $SRC is not a folder" >&2; exit 2; }
[ -e "$DEST" ] && { echo "sw2-freeze: $DEST exists; candidates are never rewritten" >&2; exit 1; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}

if [ -f "$SRC/manifest.json" ]; then
  MANIFEST=manifest.json
  [ -f "$SRC/build/report.json" ] || { echo "sw2-freeze: native app is not built (sw2 build)" >&2; exit 1; }
elif [ -f "$SRC/app.json" ]; then
  MANIFEST=app.json
else
  echo "sw2-freeze: $SRC has no manifest.json or app.json" >&2; exit 1
fi
ID=$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(process.argv[1])).id))' "$SRC/$MANIFEST")
case $ID in ''|*/*|.*) echo "sw2-freeze: bad app id '$ID'" >&2; exit 1;; esac

mkdir -p "$DEST"
cp -R "$SRC" "$DEST/$ID"
# Sources and editor state are not part of what runs.
rm -rf "$DEST/$ID/.git" "$DEST/$ID/build/obj" 2>/dev/null || true

(cd "$DEST" && find "$ID" -type f | LC_ALL=C sort | while IFS= read -r f; do sha256 "$f"; done) > "$DEST/SHA256SUMS"

commit_of() { git -C "$1" describe --always --dirty 2>/dev/null || echo unknown; }
SDK_COMMIT=unknown
[ -n "${SW2_SDK:-}" ] && SDK_COMMIT=$(commit_of "$SW2_SDK")
node -e '
const [dest, id, manifestFile, source, sdk] = process.argv.slice(1);
const fs = require("fs");
const m = JSON.parse(fs.readFileSync(manifestFile));
fs.writeFileSync(dest + "/CANDIDATE.json", JSON.stringify({
  id, name: m.name, version: String(m.version),
  kind: m.format === "hblauncher.gpu-app" ? "gpubrew" : m.kind,
  label: process.env.SW2_LABEL || "",
  sourceCommit: source, sdkCommit: sdk,
  frozen: new Date().toISOString()}, null, 2) + "\n");
' "$DEST" "$ID" "$SRC/$MANIFEST" "$(commit_of "$SRC")" "$SDK_COMMIT"

FILES=$(wc -l < "$DEST/SHA256SUMS" | tr -d ' ')
echo "frozen $ID ($FILES files) -> $DEST"
echo "next: scripts/sw2-cycle.sh $DEST"
