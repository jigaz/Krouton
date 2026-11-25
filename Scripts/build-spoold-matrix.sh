#!/usr/bin/env bash
set -euo pipefail

# Pure single-architecture native build matrix (no fat/universal lipo binaries).
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Standalone checkout of github.com/jigaz/krouton-spoold (sibling dir by default).
SPOOLD_DIR="${SPOOLD_DIR:-$ROOT_DIR/../krouton-spoold}"
DIST_DIR="$ROOT_DIR/dist"

rm -rf "$DIST_DIR/macos-universal"
mkdir -p \
  "$DIST_DIR/macos-arm64" \
  "$DIST_DIR/macos-x86_64" \
  "$DIST_DIR/windows-x86_64" \
  "$DIST_DIR/linux-aarch64" \
  "$DIST_DIR/linux-x86_64"

cd "$SPOOLD_DIR"

echo "=== 1. Native macOS Apple Silicon (aarch64-apple-darwin, macOS 12.0+) ==="
MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --release -p krouton-spoold -p spoold-verify --target aarch64-apple-darwin
cp target/aarch64-apple-darwin/release/krouton-spoold "$DIST_DIR/macos-arm64/krouton-spoold"
cp target/aarch64-apple-darwin/release/krouton-spoold-verify "$DIST_DIR/macos-arm64/krouton-spoold-verify"

echo "=== 2. Native macOS Intel (x86_64-apple-darwin, macOS 12.0+) ==="
MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --release -p krouton-spoold -p spoold-verify --target x86_64-apple-darwin
cp target/x86_64-apple-darwin/release/krouton-spoold "$DIST_DIR/macos-x86_64/krouton-spoold"
cp target/x86_64-apple-darwin/release/krouton-spoold-verify "$DIST_DIR/macos-x86_64/krouton-spoold-verify"

echo "=== 3. Native Windows x86_64 (x86_64-pc-windows-gnu) ==="
CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc \
  cargo build --release -p krouton-spoold -p spoold-verify --target x86_64-pc-windows-gnu
cp target/x86_64-pc-windows-gnu/release/krouton-spoold.exe "$DIST_DIR/windows-x86_64/krouton-spoold.exe"
cp target/x86_64-pc-windows-gnu/release/krouton-spoold-verify.exe "$DIST_DIR/windows-x86_64/krouton-spoold-verify.exe"

echo "=== 4. Native Static Linux ARM64 / Raspberry Pi 4 & 5 (aarch64-unknown-linux-musl) ==="
cargo zigbuild --release -p krouton-spoold -p spoold-verify --target aarch64-unknown-linux-musl
cp target/aarch64-unknown-linux-musl/release/krouton-spoold "$DIST_DIR/linux-aarch64/krouton-spoold"
cp target/aarch64-unknown-linux-musl/release/krouton-spoold-verify "$DIST_DIR/linux-aarch64/krouton-spoold-verify"

echo "=== 5. Native Static Linux x86_64 (x86_64-unknown-linux-musl) ==="
cargo zigbuild --release -p krouton-spoold -p spoold-verify --target x86_64-unknown-linux-musl
cp target/x86_64-unknown-linux-musl/release/krouton-spoold "$DIST_DIR/linux-x86_64/krouton-spoold"
cp target/x86_64-unknown-linux-musl/release/krouton-spoold-verify "$DIST_DIR/linux-x86_64/krouton-spoold-verify"

echo "=== 6. Generating Single-Architecture SHA-256 Manifest ==="
cd "$DIST_DIR"
shasum -a 256 \
  macos-arm64/krouton-spoold \
  macos-arm64/krouton-spoold-verify \
  macos-x86_64/krouton-spoold \
  macos-x86_64/krouton-spoold-verify \
  windows-x86_64/krouton-spoold.exe \
  windows-x86_64/krouton-spoold-verify.exe \
  linux-aarch64/krouton-spoold \
  linux-aarch64/krouton-spoold-verify \
  linux-x86_64/krouton-spoold \
  linux-x86_64/krouton-spoold-verify | tee "$DIST_DIR/SHA256SUMS.txt"

echo ""
echo "=== 7. Verifying Pure Single-Architecture Binary Headers (Zero Universal/Fat Binaries) ==="
for artifact in \
  "$DIST_DIR/macos-arm64/krouton-spoold" \
  "$DIST_DIR/macos-x86_64/krouton-spoold" \
  "$DIST_DIR/windows-x86_64/krouton-spoold.exe" \
  "$DIST_DIR/linux-aarch64/krouton-spoold" \
  "$DIST_DIR/linux-x86_64/krouton-spoold"; do
  hdr="$(file -b "$artifact")"
  echo "  $artifact -> $hdr"
  if [[ "$hdr" == *"universal"* ]]; then
    echo "ERROR: Universal fat binary detected at $artifact" >&2
    exit 1
  fi
done
