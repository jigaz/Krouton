#!/bin/sh
cd "$(dirname "$0")" || exit 1
echo "=== AI_HANDOFF.md ==="
cat AI_HANDOFF.md
echo "\n=== Uncommitted Changes (git status) ==="
git status -s
echo "\n=== Diff Stat ==="
git diff --stat
