#!/usr/bin/env bash
# Builds the app and puts W-Player-<version>.dmg into releases/v<version>/.
#   scripts/release.sh             the disk image only
#   scripts/release.sh --publish   and a GitHub release with it (needs gh)
# Signing and notarization aren't part of this script: pass SIGN_IDENTITY to build-app.sh for a signed app.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
scripts/build-app.sh

OUT="releases/v$VERSION"
DMG="$OUT/W-Player-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT"
ditto build/W-Player.app "$STAGE/W-Player.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "W-Player $VERSION" -srcfolder "$STAGE" -format UDZO -quiet "$DMG"
echo "release: $DMG"

if [ "${1:-}" = "--publish" ]; then
  NOTES="$(awk "/^## \\[$VERSION\\]/{found=1; next} /^## \\[/{if (found) exit} found" CHANGELOG.md)"
  gh release create "v$VERSION" "$DMG" --title "W-Player $VERSION" --notes "$NOTES"
fi
