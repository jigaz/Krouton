#!/usr/bin/env bash
set -euo pipefail

# Picks the Xcode CI builds with: the newest installed Xcode whose version starts with $1
# (default 27.2), so a point release (27.2.1) is used once the runner image has it. Writes
# DEVELOPER_DIR to $GITHUB_ENV for the steps that follow, and fails with the list of installed
# Xcodes when none matches, rather than quietly building with another toolchain.

WANT="${1:-27.2}"
# Only the release and its point releases: not 27.20, betas or release candidates.
WANT_PATTERN="^/Applications/Xcode_${WANT//./\\.}(\\.[0-9]+)*\\.app\$"
CANDIDATES=$(ls -d /Applications/Xcode_*.app 2>/dev/null | grep -E "$WANT_PATTERN" | sort -V || true)
CHOSEN=$(echo "$CANDIDATES" | tail -n 1)
if [ -z "$CHOSEN" ]; then
  echo "No Xcode $WANT on this runner. Installed:" >&2
  ls -d /Applications/Xcode*.app >&2 || true
  exit 1
fi
echo "DEVELOPER_DIR=$CHOSEN/Contents/Developer" >> "${GITHUB_ENV:-/dev/null}"
DEVELOPER_DIR="$CHOSEN/Contents/Developer" xcodebuild -version
DEVELOPER_DIR="$CHOSEN/Contents/Developer" swift --version
