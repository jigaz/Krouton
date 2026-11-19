#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Krouton"
BUNDLE_ID="app.krouton"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release"
APP_DIR=".build/${APP_NAME}.app"

echo "Building ${APP_NAME} (${VERSION}) in release mode..."
swift build -c release

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

for bundle in "${BUILD_DIR}"/*.bundle; do
  if [ -d "${bundle}" ]; then
    cp -R "${bundle}" "${APP_DIR}/Contents/Resources/"
  fi
done

cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSBonjourServices</key>
    <array>
        <string>_krouton-spool._tcp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Krouton uses the local network to discover and stream optical disc images to paired Krouton burn nodes.</string>
</dict>
</plist>
EOF

echo "✅ Packaged ${APP_DIR}"
