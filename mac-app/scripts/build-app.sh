#!/bin/bash
# Builds "Palette Pro.app". Pass --install to copy it into ~/Applications.
set -euo pipefail
trap 'echo "✗ Build stopped at line $LINENO: $BASH_COMMAND" >&2' ERR
cd "$(dirname "$0")/.."

# Without full Xcode, the newest SDKs need SwiftUI macro plugins that only ship with Xcode.
# Fall back to the newest macOS 26 SDK from the Command Line Tools in that case.
if ! xcode-select -p | grep -q "Xcode.*\.app"; then
  for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk; do
    if [ -d "$sdk" ]; then export SDKROOT="$sdk"; break; fi
  done
fi

# Build products live outside the project: ~/Documents may be synced by iCloud, which would upload
# the build cache and tags files with metadata that code signing rejects.
OUT="$HOME/Library/Caches/PalettePro-build"
SCRATCH="$OUT/swiftpm"

echo "› Building (release)…"
LOG="$(mktemp)"
if ! swift build -c release --product PalettePro --scratch-path "$SCRATCH" >"$LOG" 2>&1; then
  grep -v "ld: warning: search path" "$LOG"
  echo "✗ Build failed"
  exit 1
fi
rm -f "$LOG"
BIN="$(swift build -c release --scratch-path "$SCRATCH" --show-bin-path)/PalettePro"

echo "› Making the icon…"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
swiftc -O scripts/make-icon.swift -o "$WORK/make-icon" 2>&1 | grep -v "ld: warning: search path" || true
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
# Every size is drawn natively (small sizes use a simplified design), not scaled down from 1024.
for s in 16 32 128 256 512; do
  "$WORK/make-icon" "$ICONSET/icon_${s}x${s}.png" $s
  "$WORK/make-icon" "$ICONSET/icon_${s}x${s}@2x.png" $((s * 2))
done
iconutil -c icns "$ICONSET" -o "$WORK/AppIcon.icns"
cp "$ICONSET/icon_512x512@2x.png" Resources/AppIcon.png  # preview for the README

echo "› Assembling Palette Pro.app…"
APP="$OUT/Palette Pro.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PalettePro"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$WORK/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"
if ! SIGN_LOG="$(codesign --force --sign - "$APP" 2>&1)"; then echo "$SIGN_LOG"; exit 1; fi
echo "✓ Built $APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Palette Pro.app"
  ditto "$APP" "$HOME/Applications/Palette Pro.app"
  echo "✓ Installed to ~/Applications/Palette Pro.app"
fi
