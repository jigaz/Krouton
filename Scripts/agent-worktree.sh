#!/usr/bin/env bash
set -euo pipefail

# Gives a subagent its own checkout: a git worktree on a new branch from origin/main, next to
# this repository in ../krouton-agents/<name>. Agents work, commit and push only there, so two
# can run at once without touching each other's files or the main checkout.
#
#   Scripts/agent-worktree.sh add demo-kit            # branch agent/demo-kit
#   Scripts/agent-worktree.sh add demo-kit main       # start from another ref
#   Scripts/agent-worktree.sh list
#   Scripts/agent-worktree.sh remove demo-kit         # after its PR is merged or dropped

ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
AGENTS="$(dirname "$ROOT")/krouton-agents"
cmd="${1:-list}"

case "$cmd" in
  add)
    name="${2:?name}"; base="${3:-origin/main}"
    git -C "$ROOT" fetch -q origin
    mkdir -p "$AGENTS"
    git -C "$ROOT" worktree add -q -b "agent/$name" "$AGENTS/$name" "$base"
    echo "$AGENTS/$name (branch agent/$name from $base)"
    ;;
  list)
    git -C "$ROOT" worktree list
    ;;
  remove)
    name="${2:?name}"
    git -C "$ROOT" worktree remove "$AGENTS/$name"
    git -C "$ROOT" branch -D "agent/$name" 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 add <name> [base] | list | remove <name>" >&2; exit 2
    ;;
esac
