#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="VibeCleaner"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
SCRATCH_ARM="$ROOT_DIR/.build-arm64"
SCRATCH_X64="$ROOT_DIR/.build-x86_64"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"
SWIFTPM_CACHE="$ROOT_DIR/.build/swiftpm-cache"

mkdir -p "$MODULE_CACHE" "$SWIFTPM_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

SWIFT_CACHE_ARGS=(--disable-sandbox --cache-path "$SWIFTPM_CACHE" -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE" -Xcc "-fmodules-cache-path=$MODULE_CACHE")

rm -rf "$APP_DIR" "$SCRATCH_ARM" "$SCRATCH_X64"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift build -c release --triple arm64-apple-macosx13.0 --scratch-path "$SCRATCH_ARM" "${SWIFT_CACHE_ARGS[@]}"
swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path "$SCRATCH_X64" "${SWIFT_CACHE_ARGS[@]}"

lipo -create \
  "$SCRATCH_ARM/out/Products/Release/$APP_NAME" \
  "$SCRATCH_X64/out/Products/Release/$APP_NAME" \
  -output "$APP_DIR/Contents/MacOS/$APP_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
RESOURCE_BUNDLE="$SCRATCH_ARM/out/Products/Release/VibeCleaner_VibeCleaner.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
echo "Open it with: open \"$APP_DIR\""
