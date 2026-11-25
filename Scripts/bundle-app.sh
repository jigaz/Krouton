#!/usr/bin/env bash
set -euo pipefail

# Builds a strictly single-architecture native Krouton.app bundle for the target CPU
# (ARCH=arm64 or ARCH=x86_64; defaults to host `uname -m`) with its matching native
# `krouton-spoold` helper binary embedded at Contents/Helpers/krouton-spoold.

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="${ARCH:-$(uname -m)}"
VERSION="${VERSION:-1.0.0}"

case "$ARCH" in
  arm64|aarch64)
    SWIFT_ARCH="arm64"
    RUST_TARGET="aarch64-apple-darwin"
    MIN_MACOS="14.0"
    ;;
  x86_64)
    SWIFT_ARCH="x86_64"
    RUST_TARGET="x86_64-apple-darwin"
    MIN_MACOS="14.0"
    ;;
  *)
    echo "Unsupported macOS architecture: $ARCH (expected arm64 or x86_64)" >&2
    exit 1
    ;;
esac

APP_DIR="$ROOT_DIR/dist/macos-$SWIFT_ARCH/Krouton.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
HELPERS_DIR="$CONTENTS_DIR/Helpers"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== 1. Building Native $SWIFT_ARCH Krouton Swift Executable ==="
cd "$ROOT_DIR"
swift build -c release --arch "$SWIFT_ARCH" --product Krouton
SWIFT_BIN="$(swift build -c release --arch "$SWIFT_ARCH" --show-bin-path)/Krouton"

echo "=== 2. Building Native $RUST_TARGET krouton-spoold Helper Daemon ==="
cd "$ROOT_DIR/krouton-spoold"
MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --release -p krouton-spoold --target "$RUST_TARGET"
SPOOLD_BIN="$ROOT_DIR/krouton-spoold/target/$RUST_TARGET/release/krouton-spoold"

echo "=== 3. Assembling Pure Single-Architecture $SWIFT_ARCH Krouton.app Bundle ==="
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$HELPERS_DIR" "$RESOURCES_DIR"
cp "$SWIFT_BIN" "$MACOS_DIR/Krouton"
cp "$SPOOLD_BIN" "$HELPERS_DIR/krouton-spoold"
chmod +x "$MACOS_DIR/Krouton" "$HELPERS_DIR/krouton-spoold"

cat << PLIST > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Krouton</string>
  <key>CFBundleIdentifier</key>
  <string>com.krouton.opticalstudio</string>
  <key>CFBundleName</key>
  <string>Krouton</string>
  <key>CFBundleDisplayName</key>
  <string>Krouton</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS}</string>
  <key>LSArchitecturePriority</key>
  <array>
    <string>${SWIFT_ARCH}</string>
  </array>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Krouton finds Krouton Servers on your local network and sends discs to them to burn.</string>
  <key>NSBonjourServices</key>
  <array>
    <string>_krouton-spool._tcp</string>
  </array>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "=== 4. Ad-Hoc Signing Native $SWIFT_ARCH Bundle ==="
codesign --force --deep --sign - "$APP_DIR"

echo "=== 5. Verifying Native Single-Architecture Headers ==="
file "$MACOS_DIR/Krouton" "$HELPERS_DIR/krouton-spoold"
