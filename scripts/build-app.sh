#!/usr/bin/env bash
# Builds build/W-Player.app from the Swift package.
#   scripts/build-app.sh                 ad-hoc signed (runs on this Mac; others must allow it once)
#   SIGN_IDENTITY="<a signing identity>" scripts/build-app.sh
# The update key (scripts/sparkle-public-key.txt) goes into Info.plist when the file has one; a build without it never
# looks for updates.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
BUILD="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

swift build -c release --arch arm64 --product WPlayer
BIN="$(swift build -c release --arch arm64 --show-bin-path)/WPlayer"
# Sparkle.framework as SwiftPM unpacked it (its checksum is verified by SwiftPM, pinned in Package.swift/Package.resolved).
SPARKLE=.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework
[ -d "$SPARKLE" ] || { echo "$SPARKLE is missing: run swift package resolve" >&2; exit 1; }
SPARKLE_KEY="$(tr -d '[:space:]' < scripts/sparkle-public-key.txt)"
[[ -z "$SPARKLE_KEY" || "$SPARKLE_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]] || { echo "scripts/sparkle-public-key.txt isn't an EdDSA public key (44 characters of base64)" >&2; exit 1; }

APP=build/W-Player.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/WPlayer"
# SwiftPM's rpath points next to the executable in .build; in the app Sparkle is in Contents/Frameworks.
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/WPlayer"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"          # ditto keeps the framework's symlinks
# Sparkle's XPC services are for sandboxed apps only (its documentation says to remove them otherwise): W-Player isn't.
rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"
cp -R Resources/. "$APP/Contents/Resources/"
[ -f build/AppIcon.icns ] || swift scripts/make-icon.swift build/AppIcon.icns
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE NOTICE "$APP/Contents/Resources/"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" scripts/Info.plist > "$APP/Contents/Info.plist"
[ -z "$SPARKLE_KEY" ] || plutil -insert SUPublicEDKey -string "$SPARKLE_KEY" "$APP/Contents/Info.plist"

# Sparkle's own code, inside out, as Sparkle's documentation says for an app Xcode doesn't build.
sign_sparkle() {
  local framework="$APP/Contents/Frameworks/Sparkle.framework" b="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
  "$@" "$b/Autoupdate"
  "$@" "$b/Updater.app"
  "$@" "$framework"
}

if [ -n "${SIGN_IDENTITY:-}" ]; then
  SIGN=(codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY")
  sign_sparkle "${SIGN[@]}"
  "${SIGN[@]}" "$APP"
else
  sign_sparkle codesign --force --options runtime --timestamp=none --sign -
  # Without the hardened runtime: its library validation refuses a framework that isn't signed by the app's own team, and
  # an ad-hoc signature has no team, so the app couldn't load Sparkle.
  codesign --force --timestamp=none --sign - "$APP"
fi
codesign --verify --strict --deep "$APP"
echo "app: $APP ($VERSION, build $BUILD)"
