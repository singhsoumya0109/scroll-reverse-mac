#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Compiling Scroll Reverse for Apple Silicon (arm64)..."
APP_NAME="ScrollReverse"
APP_BUNDLE="${APP_NAME}.app"

rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

clang -O3 \
    -arch arm64 \
    -fobjc-arc \
    -framework Cocoa \
    -framework ApplicationServices \
    main.m \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "==> Code signing application ad-hoc..."
xattr -d com.apple.FinderInfo "${APP_BUNDLE}" 2>/dev/null || true
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Build successful! Created ${APP_BUNDLE}."
