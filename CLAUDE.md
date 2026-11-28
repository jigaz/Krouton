# CLAUDE.md — Krouton (`app.krouton`)

This file provides canonical architectural context, build/verification commands, and strict source-hygiene invariants for Claude and peer AI agents working on **Krouton**.

## 1. Essential Commands
- **Build All Targets:** `swift build`
- **Run Unit Tests:** `swift test`
- **Run Deterministic Verification Harness:** `swift run krouton-verify`
- **Krouton Server (Rust):** `cd krouton-server && cargo test --workspace && cargo clippy --workspace --all-targets`
- **Launch macOS App:** `swift run Krouton`
- **User Manual:** chapters are Markdown in `Sources/KroutonApp/Resources/Manual/` (read by the app); after editing run `python3 Scripts/build-manual.py`, and CI runs it with `--check` (also fails if a menu shortcut is missing from `manual-09-keyboard-shortcuts.md`). Describe only what works today.
- **Interface text:** `Sources/KroutonApp/Resources/Localizable.xcstrings` (String Catalog). After adding or changing text run `python3 Scripts/extract-strings.py`; CI runs it with `--check`. Write user-facing text as SwiftUI literals or `KroutonL10n.tr("…")`.
- **Package the App:** `./Scripts/bundle-app.sh` (`ARCH`, `VERSION`)
- **Open questions:** `dev-notes/open-questions.md` lists investigations and decisions waiting for an answer; check it before starting larger work, and record findings there.
- **Unused code:** CI's `unused-code` job runs Periphery (`.periphery.yml`) and lists declarations nothing uses in the job summary. It's a report, not a gate; locally, `brew install periphery && periphery scan`.

> **Mandatory Verification Rule:** Every code change or architectural proposal MUST pass `swift test && swift run krouton-verify` (and `python3 Scripts/build-manual.py --check` and `python3 Scripts/extract-strings.py --check`) with zero warnings and zero failures. Changes under `krouton-server/` or `Vectors/` must also pass `cargo test --workspace` and `cargo clippy --workspace --all-targets` (CI runs them on Linux, macOS, Windows and ARM). A wire change regenerates `Vectors/krsp-control-v1.txt` (`KRSP_WRITE_CONTROL_VECTORS=1 cargo test -p krsp --test control_vectors`), and a bundle-format change regenerates `Vectors/krsp-bundle-v1.tar` and `krsp-bundle-names-v1.txt` (`KRSP_WRITE_BUNDLE_VECTORS=1 cargo test -p krsp --test bundle_vectors`), and a change to the UDF writer's output regenerates `Vectors/udf-bd-v1.sha256` and `udf-dvd-v1.sha256` (`KRSP_WRITE_UDF_VECTORS=1 cargo test -p server-core disc::tests::udf_vector`); all are checked on both sides.

---

## 2. 11-Target Modular Architecture
Krouton is a native macOS optical disc mastering, extraction, bad-sector rescue, and distributed burn-pool suite written in **Swift 6** (`swift-tools-version: 6.0`, macOS 14+), built and checked with **Xcode 27.2 / Swift 6.4** (CI selects it with `Scripts/ci-select-xcode.sh` on the `xcode-27` runner image):

### 11 Core Architectural Modules (`KroutonDomainIdentity.Module`, 21 SPM Targets in `Package.swift`)
1. `OpticalCore` — Pure domain models, `KroutonDomainIdentity`, 28 optical format recipes, `BurnClaimLedger`, `SpanManifest`. Zero external dependencies.
2. `DriveKit` — Optical hardware discovery & low-level I/O. **Strictly isolated:** never import UI or networking frameworks here.
3. `BurnKit` — `BurnSetScheduler`, `BusArbitrationState`, `BurnPowerAndBandwidthArbiter`, APFS CoW staging.
4. `ImageKit` — Hybrid ISO-9660 / Joliet / UDF / El Torito LBA planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256), `.cue/.bin` parser, SHA-256 sector inspector, `KroutonUDFImageWriter` (UDF 2.50 for Blu-ray/AVCHD and large-file data; ISO 9660 + UDF 1.02 in player order for DVD-Video), `KroutonHFSImageWriter` (classic HFS for Mac OS 9).
5. `AudioKit` — Red Book CD-DA 75 fps (2352 B/frame) engine, lock-free `CrossfadeParameterMailbox`, `SpliceOverlapMath`, CD-Text CRC-16, CUE compiler.
6. `VideoKit` — DVD-5/DVD-9/BD-25/BD-50 bitrate budgeting, menu-preserving DVD-9 -> DVD-5 shrink & `.IFO` relinking, AVCHD authoring (M2TS analysis, BDMV/MPLS/CLPI writers).
7. `RescueKit` — Bad-sector optical rescue copy engine & archival disc quality grading.
8. `LabelKit` — 300-DPI polar disc geometry & 1:1 vector PDF print sheet engine.
9. `NetworkSpool` — Client for **Krouton Server** (`krouton-server/`, Rust): KRSP v1 frames (`SpoolWireFrame`), Merkle manifests and the resumable `SpoolUploadSender`, pairing and session proofs (`SpoolPairing`), pinned mutual TLS (`SpoolTLS`, `SpoolServerConnection`), keys (`SpoolClientIdentity`), control messages (`SpoolControl`), folder bundles for server-side mastering (`SpoolBundleWriter`), and `SpoolRemoteNodeClient` (`burnImage`, `burnFolder`). The server side of the protocol lives only in Rust. Depends only on `OpticalCore`.
10. `Persistence` — `SessionStore`, `RunLock` crash recovery.
11. `KroutonApp` — macOS application target split into `Shell/` and `Features/` (plus `KroutonVerify` and 9 module test targets = 21 SPM targets total).

---

## 3. Non-Negotiable Code Style & Verification Gates (`krouton-verify`)
All code written or proposed for Krouton is automatically linted by **Suite 1, Suite 2, and Suite 18**:

- **Pure-SwiftUI Gate (`Sources/KroutonApp/Features/` and `Sources/KroutonApp/Shell/`):**
  - Files under `Features/` and `Shell/` must use **100% Pure SwiftUI**.
  - **Strictly banned there:** `import AppKit`, `import Cocoa`, `NSColor`, `NSView`, `NSImage`, `NSViewRepresentable`, `NSApplication.shared`, `NSWorkspace`, `NSPasteboard`, and looking AppKit up at runtime (`NSClassFromString`, `NSSelectorFromString`).
  - **The one exception** is `Shell/App/KroutonAppKitBridge.swift`, for what SwiftUI on macOS has no API for (blocking Quit mid-burn, the Dock icon and badge, the clipboard, selecting files in Finder, activation). Add to it only when SwiftUI can't do the job, and call it through `KroutonOSDesktopBridge`. Emptying it is an open goal: see `dev-notes/pure-swiftui-shell.md` for what each part needs and what to check with each new SDK.
  - Use `Color.resolve(in: EnvironmentValues())` for color math and `ImageIO` (`CGImageSource`) + `Image(decorative:scale:)` for file thumbnails.
- **Strict File & Function Size Ceilings:**
  - SwiftUI View files (`*View*.swift`, `*Bar.swift`, `*Canvas.swift`): **<= 400 LOC**
  - Non-View Swift files: **<= 500 LOC**
  - Individual functions / computed bodies: **<= 200 LOC**
- **Canonical Section Headers:**
  - Any Swift file **> 120 LOC** MUST include canonical `// MARK: -` section headers.
- **Role-Based Extension Naming:**
  - Multi-file extensions of a type `Foo` MUST be named `Foo+Role.swift` (e.g., `VerifyHarness+ArchitectureSuites.swift`).
- **Zero Shell-Injection Gate (Suite 18):**
  - Never invoke shells (`/bin/sh`, `/bin/bash`, `/bin/zsh`, `popen`, `system`) or subprocess networking (`curl`, `rsync`, `nc`, `ssh`).
  - Direct `Process` execution with an explicit executable URL and argument array (e.g., `/usr/bin/hdiutil`, `ffmpeg`) is permitted only in the imaging/transcoding layers.
  - All networking and IPC must use native Apple frameworks (`Network.framework`, `URLSession`, `CryptoKit`).
- **Integration Reachability Ratchet (Suite 28 & `PENDING_INTEGRATION.md`):**
  - Every `public` type in a library target must either have a caller in another production file or be listed in `PENDING_INTEGRATION.md` with an owner and decide-by date.
  - When a listed type gains a production caller, remove its entry from `PENDING_INTEGRATION.md` so the unwired list can only shrink.
- **Portable Core Gate (Suite 31, iPad-ready):**
  - `OpticalCore`, `AudioKit`, `LabelKit`, `RescueKit`, `Persistence` and `NetworkSpool` may depend only on each other and must not import `AppKit`, `IOKit`, `DiskArbitration`, `DiscRecording`, `SystemConfiguration` or the macOS-only modules, nor use `Process`, `NSWorkspace`, `NS*` UI types or other macOS-only symbols, except inside `#if os(macOS)`.
  - CI builds these libraries for `generic/platform=iOS`; keep that job green.
- **Swift 6 Strict Concurrency & Observation:**
  - All cross-isolation models must conform to `Sendable`.
  - UI state uses `@Observable` with leaf-granular sub-stores (`let` child store + `ReferenceWritableKeyPath`, Suite 24).
  - Workspace and rack views in `Features/` and `Shell/NavigationAndRack/` provide right-click `.contextMenu`s; `krouton-verify` Suite 3 requires at least 6 such view clusters, so do not remove them.

---
