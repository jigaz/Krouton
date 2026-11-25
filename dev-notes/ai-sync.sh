#!/bin/sh
cd "$(dirname "$0")/.." || exit 1
echo "=== AI_HANDOFF.md ==="
cat dev-notes/AI_HANDOFF.md
printf '\n=== Uncommitted Changes (git status) ===\n'
git status -s
printf '\n=== Diff Stat ===\n'
git diff --stat
