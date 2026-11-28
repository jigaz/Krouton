#!/bin/sh
# Archived 2026-11-28: prints dev-notes/AI_HANDOFF.md, which is no longer updated, then the
# git status and diff stat. Kept for the record; `git log` and `git status` do the same job.
cd "$(dirname "$0")/.." || exit 1
echo "=== AI_HANDOFF.md ==="
cat dev-notes/AI_HANDOFF.md
printf '\n=== Uncommitted Changes (git status) ===\n'
git status -s
printf '\n=== Diff Stat ===\n'
git diff --stat
