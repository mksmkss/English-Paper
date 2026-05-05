#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build-release/PapersApp.app"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/PapersApp.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_DIR/PapersApp.zip"
echo "Packaged release at $DIST_DIR/PapersApp.zip"
