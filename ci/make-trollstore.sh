#!/bin/bash
# Fake-signs the unsigned MeloCafe.app in <dir>/Payload with the entitlements it needs and zips a TrollStore .tipa.
#   ci/make-trollstore.sh <dir containing Payload/> <output .tipa path>
set -euo pipefail
SRC="$(cd "$1" && pwd)"; OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
APP="$SRC/Payload/MeloCafe.app"
ent() { # <file> <keys...>
  f="$1"; shift
  { echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0"><dict>'
    for k in "$@"; do echo "<key>$k</key><true/>"; done
    echo '</dict></plist>'; } > "$f"
}
T="$(mktemp -d)"
MEM1=com.apple.developer.kernel.increased-memory-limit
MEM2=com.apple.developer.kernel.extended-virtual-addressing
ent "$T/app.plist" get-task-allow $MEM1 $MEM2
ent "$T/ext.plist" get-task-allow $MEM1
EXE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
ldid -S"$T/app.plist" "$APP/$EXE"
for appex in "$APP"/PlugIns/*.appex; do
  [ -d "$appex" ] || continue
  e="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$appex/Info.plist")"
  ldid -S"$T/ext.plist" "$appex/$e"
done
echo "== app entitlements"; ldid -e "$APP/$EXE" | grep '<key>' || true
rm -f "$OUT"; (cd "$SRC" && zip -qry "$OUT" Payload)
ls -l "$OUT"
