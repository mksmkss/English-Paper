#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build-release"
APP_DIR="$BUILD_DIR/PapersApp.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
SCRATCH_DIR="${SCRATCH_DIR:-$ROOT_DIR/.build-app}"
MODULE_CACHE_DIR="${MODULE_CACHE_DIR:-/private/tmp/english-paper-reader-module-cache}"
ICONSET_DIR="$ROOT_DIR/App/AppIcon.iconset"
ICON_PATH="$ROOT_DIR/App/PapersApp.icns"
MANUAL_BUILD_DIR="$ROOT_DIR/.build-manual"
MANUAL_BINARY_PATH="$MANUAL_BUILD_DIR/release/EnglishPaperReader"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
mkdir -p "$MODULE_CACHE_DIR" "$MANUAL_BUILD_DIR/release"

python3 "$ROOT_DIR/scripts/generate_app_icon.py"

build_with_swiftpm() {
  HOME=/private/tmp \
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  swift build -c release --package-path "$ROOT_DIR" --scratch-path "$SCRATCH_DIR"
}

build_manually() {
  local sources_list
  sources_list="$(mktemp)"
  find "$ROOT_DIR/Sources/EnglishPaperReader" -name '*.swift' | sort > "$sources_list"

  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  xargs swiftc \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    -target arm64-apple-macosx14.0 \
    -O \
    -framework SwiftUI \
    -framework PDFKit \
    -framework AppKit \
    -framework UniformTypeIdentifiers \
    -framework Combine \
    -framework Foundation \
    -framework CryptoKit \
    -lsqlite3 \
    -o "$MANUAL_BINARY_PATH" < "$sources_list"

  rm -f "$sources_list"
}

if build_with_swiftpm; then
  if [ -f "$SCRATCH_DIR/release/EnglishPaperReader" ]; then
    cp "$SCRATCH_DIR/release/EnglishPaperReader" "$MACOS_DIR/PapersApp"
  else
    cp "$SCRATCH_DIR/arm64-apple-macosx/release/EnglishPaperReader" "$MACOS_DIR/PapersApp"
  fi
else
  echo "swift build failed; falling back to direct swiftc compilation."
  build_manually
  cp "$MANUAL_BINARY_PATH" "$MACOS_DIR/PapersApp"
fi

cp "$ICON_PATH" "$RESOURCES_DIR/PapersApp.icns"

cat > "$PLIST_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>English Paper Reader</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>PDF Document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.adobe.pdf</string>
      </array>
    </dict>
  </array>
  <key>CFBundleExecutable</key>
  <string>PapersApp</string>
  <key>CFBundleIconFile</key>
  <string>PapersApp.icns</string>
  <key>CFBundleIdentifier</key>
  <string>com.masataka.englishpaperreader</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>English Paper Reader</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/PapersApp"
echo "Built app bundle at $APP_DIR"
