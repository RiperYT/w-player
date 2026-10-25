#!/usr/bin/env bash
# Builds build/W-Player.app from the Swift package.
#   scripts/build-app.sh                 ad-hoc signed (runs on this Mac; others must allow it once)
#   SIGN_IDENTITY="<a signing identity>" scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
BUILD="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

swift build -c release --arch arm64 --product WPlayer
BIN="$(swift build -c release --arch arm64 --show-bin-path)/WPlayer"

APP=build/W-Player.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WPlayer"
[ -f build/AppIcon.icns ] || swift scripts/make-icon.swift build/AppIcon.icns
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE NOTICE "$APP/Contents/Resources/"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" scripts/Info.plist > "$APP/Contents/Info.plist"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --timestamp=none --sign - "$APP"
fi
codesign --verify --strict --deep "$APP"
echo "app: $APP ($VERSION, build $BUILD)"
