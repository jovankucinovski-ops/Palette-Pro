#!/bin/bash
# Builds Palette Pro and packages it as "Palette Pro <version>.dmg" with an Applications shortcut,
# ready to copy to another Mac. The disk image is saved next to the build and shown in Finder.
set -euo pipefail
trap 'echo "✗ Packaging stopped at line $LINENO: $BASH_COMMAND" >&2' ERR
cd "$(dirname "$0")/.."

./scripts/build-app.sh
OUT="$HOME/Library/Caches/PalettePro-build"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
DMG="$OUT/Palette Pro $VERSION.dmg"

echo "› Packaging $(basename "$DMG")…"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$OUT/Palette Pro.app" "$STAGE/Palette Pro.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
# hdiutil still works on macOS 27 but prints a deprecation notice; show only real problems.
if ! DMG_LOG="$(hdiutil create -volname "Palette Pro" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" 2>&1)"; then
  echo "$DMG_LOG"; exit 1
fi
echo "✓ Created $DMG"
[ "${1:-}" = "--no-reveal" ] || open -R "$DMG"
