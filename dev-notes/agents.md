# Working with subagents

Written 2026-11-28. How a lead session hands work to subagents so they can run at the same time
without stepping on each other, and how their work comes back.

## The rules

1. **One worktree per agent.** The lead runs `Scripts/agent-worktree.sh add <name>` before
   starting an agent. That makes `../krouton-agents/<name>` on branch `agent/<name>` from
   `origin/main`. The agent's prompt names that path.
2. **Agents work only in their worktree.** They `cd` into it in every command. They never
   `checkout`, `switch`, `reset` or `stash` in the main checkout or another agent's worktree.
3. **Agents commit and push their own branch**, then open a **draft** PR against `main`
   (`gh api repos/jigaz/krouton/pulls -F draft=true …`). The PR is how the work comes back: the
   lead reviews the diff, and CI checks it.
4. **Nobody merges without the owner.** The lead merges only when the project owner says so.
5. **Before pushing**, an agent runs the checks it can here: `python3 Scripts/extract-strings.py
   --check`, `python3 Scripts/build-manual.py --check`, and `cargo test --workspace` plus
   `cargo clippy --workspace --all-targets` for changes in `krouton-server/`. There's no Swift
   toolchain in the cloud sandbox, so Swift is checked by CI (and on Losa).
6. **Split work by files.** Give two agents work that touches different files. When that can't be
   helped, merge the first PR, then have the second merge `origin/main` into its branch.
7. **Reports are short**: what changed, what was checked, and what's left, with file paths.
8. After a PR is merged or dropped: `Scripts/agent-worktree.sh remove <name>`.

Commit messages and PR bodies end with the attribution lines the session gives.

## Kinds of agent that work well here

- **Reviewer:** reads `git diff origin/main...origin/<branch>` and reports findings with file and
  line, ranked. Read-only: it needs no worktree.
- **Builder:** a self-contained change (a script, a doc, a feature behind its own files) in its
  own worktree, ending in a draft PR.
- **Auditor:** walks a flow in the code and reports dead ends; fixes only small, safe ones.
