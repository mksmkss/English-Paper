#!/bin/sh
set -eu

APP_NAME="PapersApp.app"
INSTALL_PATH="/Applications/$APP_NAME"
CONFIG_DIR="${HOME}/Library/Application Support/EnglishPaperReader"
DEFAULT_RELEASE_URL="https://github.com/mksmkss/English-Paper/releases/latest/download/PapersApp-macOS.zip"
RELEASE_URL="${PAPERS_APP_RELEASE_URL:-$DEFAULT_RELEASE_URL}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$CONFIG_DIR"

cat <<'EOF'
 __        __   _                            _          ____                       
 \ \      / /__| | ___ ___  _ __ ___   ___  | |_ ___   |  _ \ __ _ _ __   ___ _ __ 
  \ \ /\ / / _ \ |/ __/ _ \| '_ ` _ \ / _ \ | __/ _ \  | |_) / _` | '_ \ / _ \ '__|
   \ V  V /  __/ | (_| (_) | | | | | |  __/ | || (_) | |  __/ (_| | |_) |  __/ |   
    \_/\_/ \___|_|\___\___/|_| |_| |_|\___|  \__\___/  |_|   \__,_| .__/ \___|_|   
                                                                  |_|              
EOF

echo "Downloading English Paper Reader..."
curl -fL "$RELEASE_URL" -o "$tmp_dir/PapersApp-macOS.zip"

echo "Installing app..."
rm -rf "$INSTALL_PATH"
unzip -q "$tmp_dir/PapersApp-macOS.zip" -d /Applications

echo "Installation complete."
echo "App: $INSTALL_PATH"
echo "Vocabulary data will be stored in:"
echo "  $CONFIG_DIR"
