#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPOOLD_DIR="$ROOT_DIR/krouton-spoold"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p \
  "$DIST_DIR/macos-arm64" \
  "$DIST_DIR/macos-x86_64" \
  "$DIST_DIR/macos-universal" \
  "$DIST_DIR/windows-x86_64" \
  "$DIST_DIR/linux-aarch64" \
  "$DIST_DIR/linux-x86_64"

cd "$SPOOLD_DIR"

echo "=== 1. Building macOS Apple Silicon (aarch64-apple-darwin, macOS 12.0+) ==="
MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --release -p krouton-spoold -p spoold-verify --target aarch64-apple-darwin
cp target/aarch64-apple-darwin/release/krouton-spoold "$DIST_DIR/macos-arm64/krouton-spoold"
cp target/aarch64-apple-darwin/release/krouton-spoold-verify "$DIST_DIR/macos-arm64/krouton-spoold-verify"

echo "=== 2. Building macOS Intel (x86_64-apple-darwin, macOS 12.0+) ==="
MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --release -p krouton-spoold -p spoold-verify --target x86_64-apple-darwin
cp target/x86_64-apple-darwin/release/krouton-spoold "$DIST_DIR/macos-x86_64/krouton-spoold"
cp target/x86_64-apple-darwin/release/krouton-spoold-verify "$DIST_DIR/macos-x86_64/krouton-spoold-verify"

echo "=== 3. Creating Universal macOS Binaries (arm64 + x86_64) via lipo ==="
for bin in krouton-spoold krouton-spoold-verify; do
  lipo -create -output "$DIST_DIR/macos-universal/$bin" \
    "$DIST_DIR/macos-arm64/$bin" \
    "$DIST_DIR/macos-x86_64/$bin"
  chmod +x "$DIST_DIR/macos-universal/$bin"
done

echo "=== 4. Building Windows x86_64 Native Executables (x86_64-pc-windows-gnu) ==="
CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc \
  cargo build --release -p krouton-spoold -p spoold-verify --target x86_64-pc-windows-gnu
cp target/x86_64-pc-windows-gnu/release/krouton-spoold.exe "$DIST_DIR/windows-x86_64/krouton-spoold.exe"
cp target/x86_64-pc-windows-gnu/release/krouton-spoold-verify.exe "$DIST_DIR/windows-x86_64/krouton-spoold-verify.exe"

echo "=== 5. Building Static Linux ARM64 / Raspberry Pi 4 & 5 (aarch64-unknown-linux-musl) ==="
cargo zigbuild --release -p krouton-spoold -p spoold-verify --target aarch64-unknown-linux-musl
cp target/aarch64-unknown-linux-musl/release/krouton-spoold "$DIST_DIR/linux-aarch64/krouton-spoold"
cp target/aarch64-unknown-linux-musl/release/krouton-spoold-verify "$DIST_DIR/linux-aarch64/krouton-spoold-verify"

echo "=== 6. Building Static Linux x86_64 (x86_64-unknown-linux-musl) ==="
cargo zigbuild --release -p krouton-spoold -p spoold-verify --target x86_64-unknown-linux-musl
cp target/x86_64-unknown-linux-musl/release/krouton-spoold "$DIST_DIR/linux-x86_64/krouton-spoold"
cp target/x86_64-unknown-linux-musl/release/krouton-spoold-verify "$DIST_DIR/linux-x86_64/krouton-spoold-verify"

echo "=== 7. Generating SHA-256 Release Manifest ==="
cd "$DIST_DIR"
shasum -a 256 \
  macos-universal/krouton-spoold \
  macos-universal/krouton-spoold-verify \
  windows-x86_64/krouton-spoold.exe \
  windows-x86_64/krouton-spoold-verify.exe \
  linux-aarch64/krouton-spoold \
  linux-aarch64/krouton-spoold-verify \
  linux-x86_64/krouton-spoold \
  linux-x86_64/krouton-spoold-verify | tee "$DIST_DIR/SHA256SUMS.txt"
