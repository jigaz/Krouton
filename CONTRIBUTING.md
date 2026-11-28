# Contributing to Krouton

Thanks for helping. Krouton aims to be the disc-burning app that is still maintained in ten years, so every change passes a few strict, automated checks. This page gets you from a fresh clone to a pull request.

## 1. Get the code and build it

You need:

- A Mac with macOS 14 or later and Xcode 27.2 (Swift 6.4). CI uses the same toolchain on the `xcode-27` runner image.
- Python 3 for the manual and string catalog scripts (standard library only).
- For Krouton Server: Rust 1.88 or later (`rustup`), plus `xorriso` on Linux if you want the real mastering tests to run.

```bash
git clone https://github.com/jigaz/Krouton.git
cd Krouton
swift build
swift run Krouton
```

For the widget and App Intents you need the Xcode project: `brew install xcodegen && cd XcodeHost && xcodegen generate`, then open `XcodeHost/Krouton.xcodeproj`. Set your own team for signed builds. Everything else builds with SwiftPM alone.

## 2. Run the gates

Every change must pass these with zero warnings and zero failures. The package builds with `-warnings-as-errors`.

```bash
swift test && swift run krouton-verify
python3 Scripts/build-manual.py --check
python3 Scripts/extract-strings.py --check
```

Changes under `krouton-server/` or `Vectors/` must also pass:

```bash
cd krouton-server
cargo test --workspace
cargo clippy --workspace --all-targets
cargo fmt --all --check
```

CI runs all of this on every pull request to `main`. `ci.yml` builds, tests and verifies the app, builds the Xcode project, compiles the portable modules for iPadOS and lists unused code (a report, not a gate). `krouton-server.yml` tests the server and builds it for Linux, macOS and Windows on x86 and ARM, when `krouton-server/` or `Vectors/` changes.

## 3. Where things live

| Module | What it does |
|---|---|
| `OpticalCore` | Domain models, format recipes and the MMC command codec. Depends on nothing. |
| `DriveKit` | Drive discovery and I/O through DiscRecording and IOKit. |
| `BurnKit` | Multi-drive burn sets and APFS copy-on-write staging. |
| `ImageKit` | ISO 9660, Joliet, UDF and HFS image writers, `.cue/.bin` parsing. |
| `AudioKit` | Red Book audio, CD-Text, crossfades, CUE sheets. |
| `VideoKit` | DVD and Blu-ray budgeting, DVD-9 shrink, AVCHD authoring. |
| `RescueKit` | Damaged-disc rescue and quality grading. |
| `LabelKit` | Disc label geometry and print sheets. |
| `NetworkSpool` | The client for Krouton Server. |
| `Persistence` | Session store, crash recovery, burn journal. |
| `KroutonApp` | The SwiftUI app: `Shell/` (app, windows, menus, settings, services) and `Features/` (the workspaces). |

[ARCHITECTURE.md](ARCHITECTURE.md) has the dependency rules and the full list of verification suites. Interface text lives in `Sources/KroutonApp/Resources/Localizable.xcstrings`; the user manual in `Sources/KroutonApp/Resources/Manual/`.

## 4. Pick something to work on

- **[`dev-notes/open-questions.md`](dev-notes/open-questions.md)** lists investigations and decisions waiting for an answer: hardware tests, correctness checks and architecture questions. Each says what is known, where to look and who decides. Entries marked **Owner decides** need the owner's agreement before you change code; write up what you found first.
- **[`PENDING_INTEGRATION.md`](PENDING_INTEGRATION.md)** lists public library types that nothing calls yet. Wiring one in, or making the case to delete it, is a self-contained task.
- Issues labelled `good first issue` or `help wanted`.
- For anything large, open an issue first so we can agree on the approach.

## 5. Rules `krouton-verify` enforces

`krouton-verify` reads the source tree and runs the domain checks. The rules you are most likely to meet, with the suite that checks each:

1. **Module boundaries (Suites 1 and 31).** Modules import only what [ARCHITECTURE.md](ARCHITECTURE.md) allows. `OpticalCore`, `AudioKit`, `LabelKit`, `RescueKit`, `Persistence` and `NetworkSpool` must also build for iPadOS: no `AppKit`, `IOKit`, `DiscRecording`, `Process` or other macOS-only symbols outside `#if os(macOS)`.
2. **Pure SwiftUI in `Features/` and `Shell/` (Suite 2).** No `import AppKit`, `NSColor`, `NSView`, `NSImage`, `NSViewRepresentable`, `NSWorkspace`, `NSPasteboard` or runtime AppKit lookups. The one exception is `Shell/App/KroutonAppKitBridge.swift`, for what SwiftUI can't do yet; see [`dev-notes/pure-swiftui-shell.md`](dev-notes/pure-swiftui-shell.md).
3. **Size limits (Suite 2).** View files (`*View*.swift`, `*Bar.swift`, `*Canvas.swift`) at most 400 lines, other files 500, any function or computed body 200. Files over 120 lines need `// MARK: -` section headers.
4. **Naming (Suite 2).** An extension of `Foo` in its own file is `Foo+Role.swift`.
5. **Imports (Suite 2)** are alphabetical in byte order (`OSLog` sorts before `OpticalCore`) and unique.
6. **Context menus (Suite 3).** At least six workspace and rack views keep their right-click menus.
7. **No shells (Suite 18).** Never run `/bin/sh`, `bash`, `zsh`, `popen` or `system`, or `curl`, `rsync`, `nc` or `ssh`. The imaging and video layers may run a tool such as `hdiutil` or `ffmpeg` with `Process`, an explicit executable URL and an argument array. Networking uses Apple frameworks.
8. **Nothing unwired (Suite 28).** Every `public` type in a library needs a caller in another production file, or an entry in `PENDING_INTEGRATION.md` with an owner and a decide-by date. When you wire a listed type, delete its entry in the same commit.
9. **Shared vectors (Suites 29 and 36).** KRSP frames, control messages, folder bundles and UDF images must match the files in `Vectors/` byte for byte, on both the Swift and the Rust side.

Swift 6 strict concurrency is on everywhere. `@unchecked Sendable` and `nonisolated(unsafe)` are banned (Suite 1); find a design the compiler can check. Write interface text as SwiftUI literals or `KroutonL10n.tr("…")`, then run `python3 Scripts/extract-strings.py`.

## 6. Testing without a burner

- `swift test` and `swift run krouton-verify` need no drive. The harness drives scripted drives, a scripted scratched disc and a fake network transport.
- To test burning over the network, run Krouton Server from source with the simulated backend:

  ```bash
  cd krouton-server
  cargo run -p krouton-server -- init --home /tmp/krouton-server --backend simulate
  cargo run -p krouton-server -- run --home /tmp/krouton-server
  # in a second terminal, then pair from Settings › Burners & Network:
  cargo run -p krouton-server -- pair --home /tmp/krouton-server
  ```

- For anything that touches a real burn, say in the pull request which drive and which discs you used.

## 7. Changing the protocol, bundle format or UDF writer

These are shared with Krouton Server. If you change one, regenerate its vectors from the Rust side and commit them with the change:

```bash
cd krouton-server
KRSP_WRITE_CONTROL_VECTORS=1 cargo test -p krsp --test control_vectors
KRSP_WRITE_BUNDLE_VECTORS=1 cargo test -p krsp --test bundle_vectors
KRSP_WRITE_UDF_VECTORS=1 cargo test -p server-core disc::tests::udf_vector
```

Then run `swift run krouton-verify` to confirm the Swift side agrees.

## 8. Writing documentation

- **The user manual** is the Markdown in `Sources/KroutonApp/Resources/Manual/`. The app reads it directly. After editing, run `python3 Scripts/build-manual.py` and commit the regenerated `docs/manual/`. The check also fails if a menu shortcut is missing from the keyboard shortcuts chapter.
- Write for someone burning a disc, not for a developer: what to click, what happens, what to do when it fails. Name controls exactly as the app does.
- Only describe what works today. If a feature is unfinished, say so plainly.
- The website is static HTML in `docs/` with one shared stylesheet, `docs/assets/site.css`. It loads nothing from other sites.

## 9. Pull requests

- Branch from `main` and open a pull request. Keep commits focused, with a subject that says what changed.
- Fill in the pull request template: what changed, how you tested it, which gates you ran.
- Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md) for anything a user or a server operator would notice.
- Keep to the [code of conduct](CODE_OF_CONDUCT.md).

## AI agents in this project

Krouton is developed with help from AI coding agents; the logs in `dev-notes/` record those sessions. [CLAUDE.md](CLAUDE.md) holds the same rules as this page, written for agents. When several agents work at once, each works in its own git worktree and branch and opens a draft pull request; [`dev-notes/agents.md`](dev-notes/agents.md) describes how. Agent pull requests go through the same gates and review as anyone else's, and only the owner merges. You don't need to use an agent to contribute.

## Reporting drives

You can help without writing code: burn a disc and send a drive report (see [krouton.app/drives](https://krouton.app/drives/)). Reports go into the open record at [archive.krouton.app](https://archive.krouton.app).

## Security problems

Please don't open a public issue. See [SECURITY.md](SECURITY.md).
