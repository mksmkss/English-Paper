#!/bin/sh
set -eu

APP_NAME="PapersApp.app"
INSTALL_PATH="/Applications/$APP_NAME"
LIBRARY_DIR="${HOME}/Documents/EnglishPaperReader Library"
CONFIG_DIR="${HOME}/Library/Application Support/EnglishPaperReader"
CONFIG_PATH="${CONFIG_DIR}/config.json"
DEFAULT_RELEASE_URL="https://github.com/mksmkss/English-Paper/releases/latest/download/PapersApp-macOS.zip"
RELEASE_URL="${PAPERS_APP_RELEASE_URL:-$DEFAULT_RELEASE_URL}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$LIBRARY_DIR/.paperapp"
mkdir -p "$CONFIG_DIR"

echo "Downloading English Paper Reader..."
curl -fL "$RELEASE_URL" -o "$tmp_dir/PapersApp-macOS.zip"

echo "Installing app..."
rm -rf "$INSTALL_PATH"
unzip -q "$tmp_dir/PapersApp-macOS.zip" -d /Applications

cat > "$CONFIG_PATH" <<EOF
{"libraryPath":"$LIBRARY_DIR"}
EOF

echo "Installation complete."
echo "App: $INSTALL_PATH"
echo "Library folder: $LIBRARY_DIR"
echo "Vocabulary data will be stored in $LIBRARY_DIR/.paperapp"
