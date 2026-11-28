# Development notes

Working logs from AI-assisted development sessions. These are records, not product documentation; for the project itself, start with the top-level `README.md`, `ARCHITECTURE.md` and `CLAUDE.md`.

- `AI_HANDOFF.md`: running change log across Claude Code and Gemini sessions.
- `ABACUS_CODE_SWARM_HANDOFF.md`: review handoff prepared for the Abacus.AI code swarm.
- `project_history.md`: version-by-version architecture history up to 1.0.1. Newer changes are in `CHANGELOG.md`.
- `original-specification.md`: the brief Krouton was first built from (historical; its "Bakery" names and REST daemon were not adopted).
- `ai-sync.sh`: prints the handoff log plus the current git status and diff stat (run from anywhere).
- `removed-formats.md`: formats taken out of Krouton (CD+G, SACD-R, PS3) and what bringing one back would take.
- `pure-swiftui-shell.md`: **open investigation.** What still needs AppKit in `Shell/App/KroutonAppKitBridge.swift`, what SwiftUI offers instead, and what to check with each new macOS SDK.
- `open-questions.md`: **open questions for agents**: hardware tests, honesty and correctness checks, and architecture decisions, each with what's known, where to look and who decides.
- `demo.md`: the demo kit (`Scripts/demo/`): a drive-less Krouton Server on the same Mac and generated sample files, for showing real burns without a burner or discs.
