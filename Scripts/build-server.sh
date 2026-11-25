#!/usr/bin/env bash
# Builds Krouton Server for this Mac (Apple Silicon and Intel) into dist/.
# The full matrix (Windows x64/x86/ARM64, Linux x86_64/ARM64/ARMv7/ARMv6/x86, macOS) is built by
# .github/workflows/krouton-server.yml on every pull request; download the artifacts there.
set -euo pipefail
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/krouton-server"
cargo test --workspace
for target in aarch64-apple-darwin x86_64-apple-darwin; do
  rustup target add "$target" >/dev/null
  MACOSX_DEPLOYMENT_TARGET=12.0 cargo build --release -p krouton-server --target "$target"
  out="$ROOT/dist/krouton-server-macos-${target%%-*}"
  mkdir -p "$out"
  cp "target/$target/release/krouton-server" "$out/"
  cp -R deploy README.md "$out/"
  file "$out/krouton-server"
done
(cd "$ROOT/dist" && shasum -a 256 krouton-server-macos-*/krouton-server | tee SHA256SUMS.txt)
