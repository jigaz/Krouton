#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="D3BJL3F92P"
echo "==> Building Krouton (Release)..."
swift build --disable-sandbox -c release --product Krouton

APP_DIR="$ROOT_DIR/build/Krouton.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp ".build/release/Krouton" "$APP_DIR/Contents/MacOS/Krouton"
cp "XcodeHost/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/PrivacyInfo.xcprivacy" "$APP_DIR/Contents/Resources/PrivacyInfo.xcprivacy"

for icns in AppIcon AppIcon-Dark AppIcon-Light AppIcon-Clear AppIcon-Tinted; do
  if [ -f "Resources/${icns}.icns" ]; then
    cp "Resources/${icns}.icns" "$APP_DIR/Contents/Resources/${icns}.icns"
  fi
done

if [ -d ".build/release/krouton_KroutonApp.bundle" ]; then
  cp -R ".build/release/krouton_KroutonApp.bundle" "$APP_DIR/Contents/Resources/"
fi

# Auto-detect Developer ID Application certificate for Team D3BJL3F92P; fall back to ad-hoc signing locally
DEV_ID_CERT="$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | grep "$TEAM_ID" | head -n 1 | awk -F '"' '{print $2}' || true)"

if [ -n "$DEV_ID_CERT" ]; then
  echo "==> Signing $APP_DIR with Developer ID: $DEV_ID_CERT (Hardened Runtime)"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "XcodeHost/Krouton.entitlements" \
    --sign "$DEV_ID_CERT" "$APP_DIR"
else
  echo "==> No Developer ID Application ($TEAM_ID) found in Keychain; applying local ad-hoc signature"
  codesign --force --deep --entitlements "XcodeHost/Krouton.entitlements" --sign - "$APP_DIR"
fi

echo "==> Packaged $APP_DIR"
"$APP_DIR/Contents/MacOS/Krouton" --version
