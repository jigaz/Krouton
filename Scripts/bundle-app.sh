#!/usr/bin/env bash
set -euo pipefail

# Builds Krouton.app for one CPU architecture and zips it for a release.
#
#   ./Scripts/bundle-app.sh                    # this Mac's architecture, version 1.0.0
#   ARCH=x86_64 VERSION=1.1.0 ./Scripts/bundle-app.sh
#
# Output: dist/macos-<arch>/Krouton.app and dist/Krouton-<version>-macOS-<arch>.zip, the file
# the Homebrew cask in Packaging/Homebrew/Casks downloads. Signs with a "Developer ID
# Application" certificate for team D3BJL3F92P when the keychain has one, otherwise ad hoc
# (fine for your own Mac, not for distribution). Notarize the zip separately with notarytool.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="${ARCH:-$(uname -m)}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
TEAM_ID="D3BJL3F92P"

case "$ARCH" in
  arm64|aarch64) SWIFT_ARCH="arm64" ;;
  x86_64)        SWIFT_ARCH="x86_64" ;;
  *) echo "Unsupported architecture: $ARCH (expected arm64 or x86_64)" >&2; exit 1 ;;
esac

APP_DIR="$ROOT_DIR/dist/macos-$SWIFT_ARCH/Krouton.app"
CONTENTS_DIR="$APP_DIR/Contents"
ZIP_PATH="$ROOT_DIR/dist/Krouton-$VERSION-macOS-$SWIFT_ARCH.zip"

echo "=== 1. Building Krouton for $SWIFT_ARCH ==="
cd "$ROOT_DIR"
# Newer toolchains default to the swift-build backend, which can't load this package yet
# ("Unknown error parsing property list"); use SwiftPM's own build system where it's offered.
BUILD_SYSTEM=()
if swift build --help 2>/dev/null | grep -q -- "--build-system"; then
  BUILD_SYSTEM=(--build-system native)
fi
swift build ${BUILD_SYSTEM[@]+"${BUILD_SYSTEM[@]}"} -c release --arch "$SWIFT_ARCH" --product Krouton
BIN_DIR="$(swift build ${BUILD_SYSTEM[@]+"${BUILD_SYSTEM[@]}"} -c release --arch "$SWIFT_ARCH" --show-bin-path)"

echo "=== 2. Assembling Krouton.app ==="
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/Krouton" "$CONTENTS_DIR/MacOS/Krouton"
cp "XcodeHost/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
cp "Resources/PrivacyInfo.xcprivacy" "$CONTENTS_DIR/Resources/"
for icns in AppIcon AppIcon-Dark AppIcon-Light AppIcon-Clear AppIcon-Tinted; do
  if [ -f "Resources/$icns.icns" ]; then cp "Resources/$icns.icns" "$CONTENTS_DIR/Resources/"; fi
done
# SwiftPM's resource bundle: the manual, localization catalog and asset catalog. Without it the
# app only finds its resources on the machine that built it.
RESOURCE_BUNDLE="$BIN_DIR/krouton_KroutonApp.bundle"
if [ ! -d "$RESOURCE_BUNDLE" ]; then
  echo "Missing $RESOURCE_BUNDLE" >&2
  exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$CONTENTS_DIR/Resources/"

echo "=== 3. Signing ==="
DEV_ID_CERT="$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | grep "$TEAM_ID" | head -n 1 | awk -F '"' '{print $2}' || true)"
if [ -n "$DEV_ID_CERT" ]; then
  echo "Developer ID: $DEV_ID_CERT (hardened runtime)"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "XcodeHost/Krouton.entitlements" --sign "$DEV_ID_CERT" "$APP_DIR"
else
  echo "No Developer ID certificate for $TEAM_ID in the keychain; signing ad hoc"
  codesign --force --deep --entitlements "XcodeHost/Krouton.entitlements" --sign - "$APP_DIR"
fi
codesign --verify --strict "$APP_DIR"

echo "=== 4. Checking ==="
file "$CONTENTS_DIR/MacOS/Krouton"
"$CONTENTS_DIR/MacOS/Krouton" --version

echo "=== 5. Zipping ==="
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH"
echo "Done: $ZIP_PATH"
