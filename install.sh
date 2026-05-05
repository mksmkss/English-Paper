#!/bin/sh
set -eu

APP_NAME="PapersApp.app"
INSTALL_PATH="/Applications/$APP_NAME"
REPO_DIR="${HOME}/papers-app"
APP_SUPPORT_DIR="$REPO_DIR/.paperapp"
RELEASE_URL="${PAPERS_APP_RELEASE_URL:-}"

if [ -z "$RELEASE_URL" ]; then
  echo "Set PAPERS_APP_RELEASE_URL to the latest release zip URL before running install.sh."
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$REPO_DIR"
mkdir -p "$APP_SUPPORT_DIR"

echo "Downloading release..."
curl -L "$RELEASE_URL" -o "$tmp_dir/PapersApp.zip"

echo "Installing app..."
rm -rf "$INSTALL_PATH"
unzip -q "$tmp_dir/PapersApp.zip" -d /Applications

echo "Installing git hook..."
"$(dirname "$0")/scripts/install-pre-commit.sh" "$REPO_DIR"

if [ ! -f "$APP_SUPPORT_DIR/backup.sql" ]; then
  cp "$(dirname "$0")/.paperapp/backup.sql" "$APP_SUPPORT_DIR/backup.sql"
fi

echo "Installation complete."
echo "On first launch, choose $REPO_DIR (or another repo folder) when prompted."
