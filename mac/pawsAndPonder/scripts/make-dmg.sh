#!/bin/bash
# Builds a Release version of the app and packages it as a DMG in dist/.
#
# Usage:
#   scripts/make-dmg.sh                                    # ad-hoc signed, no Apple account needed
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="pawsAndPonder.xcodeproj"
SCHEME="pawsAndPonder"
VOLUME_NAME="Paws and Ponder"
DMG_PATH="dist/Paws-and-Ponder.dmg"
# "-" means ad-hoc: a valid signature that doesn't identify a developer.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "==> Building Release"
rm -rf build
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'platform=macOS' -derivedDataPath build build -quiet

APP="$(find build/Build/Products/Release -maxdepth 1 -name '*.app' | head -n 1)"
[ -n "$APP" ] || { echo "error: no .app found after the build" >&2; exit 1; }

if [ "$SIGN_IDENTITY" != "-" ]; then
    echo "==> Signing with: $SIGN_IDENTITY"
    # Hardened Runtime and a secure timestamp are both required for notarization.
    codesign --force --options runtime --timestamp --preserve-metadata=entitlements \
        --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

echo "==> Creating $DMG_PATH"
STAGING="$(mktemp -d)"
trap 'rm -rf "${STAGING:?}"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # so the DMG offers drag-to-install
mkdir -p dist
rm -f "$DMG_PATH"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH" -quiet

echo "==> Done"
ls -lh "$DMG_PATH"
shasum -a 256 "$DMG_PATH"
