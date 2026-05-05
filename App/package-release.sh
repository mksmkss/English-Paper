#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build-release/PapersApp.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/PapersApp-macOS.zip"
DMG_PATH="$DIST_DIR/PapersApp.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
VOLUME_NAME="English Paper Reader"
APP_CERT="${DEVELOPER_ID_APP_CERT:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH" "$DMG_PATH"
rm -rf "$STAGING_DIR"

"$ROOT_DIR/App/build-app.sh"

if [ -n "$APP_CERT" ]; then
  codesign --force --deep --timestamp --options runtime --sign "$APP_CERT" "$APP_PATH"
  codesign --verify --deep --strict "$APP_PATH"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
hdiutil_success=false
if hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"; then
  hdiutil_success=true
fi

if [ "$hdiutil_success" = true ] && [ -n "$APP_CERT" ]; then
  codesign --force --timestamp --sign "$APP_CERT" "$DMG_PATH"
fi

if [ "$hdiutil_success" = true ] && [ -n "$APP_CERT" ] && [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler staple "$DMG_PATH"
fi

echo "Created release zip at $ZIP_PATH"
if [ "$hdiutil_success" = true ]; then
  echo "Created release DMG at $DMG_PATH"
else
  echo "Skipped DMG creation because hdiutil is unavailable in this environment."
fi
