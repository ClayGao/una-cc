#!/bin/bash
set -euo pipefail

APP_NAME="una-cc"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_STAGING="${BUILD_DIR}/dmg-staging"
DMG_OUTPUT="${BUILD_DIR}/${APP_NAME}.dmg"

echo "=== Building ${APP_NAME} ==="

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Compile Swift — universal binary (arm64 + x86_64)
echo "Compiling..."
swiftc -O \
  -target arm64-apple-macosx13.0 \
  -o "${BUILD_DIR}/${APP_NAME}-arm64" \
  -framework Cocoa \
  -framework AVFoundation \
  -framework CoreText \
  -framework NaturalLanguage \
  UnaCompanion.swift

swiftc -O \
  -target x86_64-apple-macosx13.0 \
  -o "${BUILD_DIR}/${APP_NAME}-x86_64" \
  -framework Cocoa \
  -framework AVFoundation \
  -framework CoreText \
  -framework NaturalLanguage \
  UnaCompanion.swift

lipo -create \
  "${BUILD_DIR}/${APP_NAME}-arm64" \
  "${BUILD_DIR}/${APP_NAME}-x86_64" \
  -output "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Bundle resources
echo "Bundling resources..."
cp Info.plist "${APP_BUNDLE}/Contents/"
cp -R assets-v10 "${APP_BUNDLE}/Contents/Resources/"
cp -R voice-lines "${APP_BUNDLE}/Contents/Resources/"
cp -R sounds "${APP_BUNDLE}/Contents/Resources/"

# App icon
cp assets/una-icon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Ad-hoc code sign (must be after all resources are in place)
echo "Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# Create DMG
echo "Creating DMG..."
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING}" \
  -ov -format UDZO \
  "${DMG_OUTPUT}"

echo "=== Done: ${DMG_OUTPUT} ==="
ls -lh "${DMG_OUTPUT}"
