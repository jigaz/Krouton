# Developer notes

Notes for people working on Krouton's code: open questions, investigations, plans and decisions
that don't belong in the user manual. Read the top-level `README.md`, `CONTRIBUTING.md` and
`ARCHITECTURE.md` first. `CLAUDE.md` has the build commands and the checks every change must pass.

Index checked 2026-11-28.

## Current notes

| Note | What it's for | Read it if you | Status |
|---|---|---|---|
| [`open-questions.md`](open-questions.md) | Investigations and decisions waiting for an answer, each with what's known, how to answer it, whether it needs hardware, and who decides. | want something to work on. Start here. | Current; checked against `main` 2026-11-28 |
| [`../PENDING_INTEGRATION.md`](../PENDING_INTEGRATION.md) | Public library types nothing uses yet, each with a plan and a decide-by date. `krouton-verify` Suite 28 reads it. | add or wire up a public type. | Current; checked 2026-11-28 |
| [`pure-swiftui-shell.md`](pure-swiftui-shell.md) | What is still AppKit in `Shell/App/KroutonAppKitBridge.swift`, what SwiftUI offers instead, and what to check with each new macOS SDK. | touch the app shell or the AppKit bridge. | Open investigation; checked against the macOS 27 SDK 2026-11-26 |
| [`icloud.md`](icloud.md) | What syncs through iCloud and what stays on each Mac, the developer-account setup, signing, and a test checklist. | work on settings sync, projects in iCloud Drive, or signing. | Current, 2026-11-28 |
| [`live-updates-iphone-watch-mac.md`](live-updates-iphone-watch-mac.md) | The plan for burn progress outside the window: Mac Live Activities, iPhone and Apple Watch. | work on the widget extension or Live Activities. | Plan, parked; updated 2026-11-28 |
| [`removed-formats.md`](removed-formats.md) | Formats taken out of Krouton (CD+G, SACD-R, PS3) and what bringing one back would take. | want to add a disc format. | Current, 2026-11-26 |
| [`agents.md`](agents.md) | How a lead session runs AI subagents in their own git worktrees, and how their work comes back as draft PRs. | use AI coding agents on this repository. | Current, 2026-11-28 |

## Archive

Records from the first AI-assisted sessions, kept for the record. They are not maintained and
may contradict the code. Each one says so at the top. For history, use `git log` and
`CHANGELOG.md`.

| Note | What it was |
|---|---|
| [`original-specification.md`](original-specification.md) | The brief Krouton was first built from. Its "Bakery" names (Toaster, Slice, Krumb) and REST daemon were not adopted. |
| [`project_history.md`](project_history.md) | A version-by-version summary up to 1.0.1 (2026-11-17). |
| [`AI_HANDOFF.md`](AI_HANDOFF.md) | An automatic per-commit log from 2026-11-17 to 2026-11-19. |
| [`ABACUS_CODE_SWARM_HANDOFF.md`](ABACUS_CODE_SWARM_HANDOFF.md) | A one-off brief for an external AI code review, 2026-11-18. |
| [`ai-sync.sh`](ai-sync.sh) | A script that prints `AI_HANDOFF.md` with the git status. |

## Writing a note

- Put the date and a status line at the top: open, current, plan, or archived.
- Say what is true today, and check the code before describing behaviour.
- Add the note to the table above. When a note's work is done, move what's still useful into the
  code, the manual or `CHANGELOG.md`, then move the note to the archive or delete it.
