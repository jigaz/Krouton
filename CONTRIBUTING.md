# Contributing to Krouton

Thanks for helping. Krouton aims to be the disc-burning app that is still maintained in ten years, so changes are held to a few strict, automated rules. This page explains them and how to check your work before you send it.

## Setting up

- Xcode 26 on macOS 14 or later (CI uses `macos-26`).
- For Krouton Server: Rust 1.88 or later (`rustup`), plus `xorriso` on Linux if you want the real mastering tests to run.
- Python 3 for the manual and site scripts (standard library only).

```bash
swift build
swift run Krouton
```

## The gate

Every change must pass, with no warnings (the package builds with `-warnings-as-errors`):

```bash
swift test && swift run krouton-verify
python3 Scripts/build-manual.py --check
```

Changes under `krouton-server/` or `Vectors/` must also pass:

```bash
cd krouton-server
cargo test --workspace
cargo clippy --workspace --all-targets
cargo fmt --all --check
```

CI runs all of this on every pull request: `ci.yml` builds and verifies the app on macOS and compiles the portable modules for iPadOS; `krouton-server.yml` tests and builds the server for Linux, macOS and Windows on x86 and ARM.

## Rules `krouton-verify` enforces

`krouton-verify` is a Swift executable that reads the source tree and runs the domain checks. The main rules, with the suite that checks each:

1. **Module boundaries (Suites 1 and 31).** Modules may only import what [ARCHITECTURE.md](ARCHITECTURE.md) allows. `OpticalCore`, `AudioKit`, `LabelKit`, `RescueKit`, `Persistence` and `NetworkSpool` must also build for iPadOS: no `AppKit`, `IOKit`, `DiscRecording`, `Process` or other macOS-only symbols outside `#if os(macOS)`.
2. **Pure SwiftUI in `Features/` (Suite 2).** No `import AppKit`, `NSColor`, `NSView`, `NSImage` or `NSViewRepresentable` under `Sources/KroutonApp/Features/`.
3. **Size limits (Suite 2).** View files (`*View*.swift`, `*Bar.swift`, `*Canvas.swift`) at most 400 lines, other files 500, any function or computed body 200. Files over 120 lines need `// MARK: -` section headers.
4. **Naming.** An extension of `Foo` in its own file is `Foo+Role.swift`, next to a `Foo.swift`.
5. **Imports** are alphabetical (byte order: `OSLog` sorts before `OpticalCore`) and unique.
6. **Context menus (Suite 3).** At least six workspace and rack views keep their right-click menus.
7. **No shells (Suite 18).** Never run `/bin/sh`, `bash`, `zsh`, `popen` or `system`, or `curl`, `rsync`, `nc` or `ssh`. The imaging and video layers may run a tool such as `hdiutil` or `ffmpeg` with `Process`, an explicit executable URL and an argument array. Networking uses Apple frameworks.
8. **Nothing unwired (Suite 28).** Every `public` type in a library needs a caller in another production file, or an entry in [PENDING_INTEGRATION.md](PENDING_INTEGRATION.md) with an owner and a decide-by date. When you wire a listed type, delete its entry in the same commit.
9. **Shared vectors (Suites 27 and 29).** KRSP frames, control messages and folder bundles must match the files in `Vectors/` byte for byte, on both the Swift and the Rust side.

Swift 6 strict concurrency is on everywhere. `@unchecked Sendable` and `nonisolated(unsafe)` are not allowed; find a design that the compiler can check.

## Changing the protocol or bundle format

The KRSP wire format and the folder bundle format are shared with Krouton Server. If you change either, regenerate the vectors from the Rust side and commit them with the change:

```bash
cd krouton-server
KRSP_WRITE_CONTROL_VECTORS=1 cargo test -p krsp --test control_vectors
KRSP_WRITE_BUNDLE_VECTORS=1 cargo test -p krsp --test bundle_vectors
```

Then run `swift run krouton-verify` to confirm the Swift side agrees.

## Writing documentation

- **The user manual** is the Markdown in `Sources/KroutonApp/Resources/Manual/`. The app reads it directly. After editing, run `python3 Scripts/build-manual.py` and commit the regenerated `docs/manual/`. The check also fails if a menu shortcut is missing from the keyboard shortcuts chapter.
- Write for someone burning a disc, not for a developer: what to click, what happens, what to do when it fails. Name controls exactly as the app does.
- Only describe what works today. If a feature is unfinished, say so plainly.
- The website is static HTML in `docs/` with one shared stylesheet, `docs/assets/site.css`, which is identical in the archive repository. It loads nothing from other sites.

## Commits and pull requests

- Branch from `main` and open a pull request. Keep commits focused, with a subject that says what changed.
- Describe how you tested: on which drive and with which discs, for anything that touches burning.
- Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md) for anything a user or a server operator would notice.

## Reporting drives

You can help without writing code: burn a disc and send a drive report (see [krouton.app/drives](https://krouton.app/drives/)). Reports go into the open record at [archive.krouton.app](https://archive.krouton.app).
