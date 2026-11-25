# CLAUDE.md — Krouton (`app.krouton`)

This file provides canonical architectural context, build/verification commands, and strict source-hygiene invariants for Claude and peer AI agents working on **Krouton**.

## 1. Essential Commands
- **Build All Targets:** `swift build`
- **Run Unit Tests:** `swift test`
- **Run Deterministic Verification Harness:** `swift run krouton-verify`
- **Krouton Server (Rust):** `cd krouton-server && cargo test --workspace && cargo clippy --workspace --all-targets`
- **Launch macOS App:** `swift run Krouton`

> **Mandatory Verification Rule:** Every code change or architectural proposal MUST pass `swift test && swift run krouton-verify` with zero warnings and zero failures. Changes under `krouton-server/` or `Vectors/` must also pass `cargo test --workspace` and `cargo clippy --workspace --all-targets` (CI runs them on Linux, macOS, Windows and ARM). A wire change regenerates `Vectors/krsp-control-v1.txt` (`KRSP_WRITE_CONTROL_VECTORS=1 cargo test -p krsp --test control_vectors`) and is checked on both sides.

---

## 2. 11-Target Modular Architecture
Krouton is a native macOS optical disc mastering, extraction, bad-sector rescue, and distributed burn-pool suite written in **Swift 6** (`swift-tools-version: 6.0`, macOS 14+):

### 11 Core Architectural Modules (`KroutonDomainIdentity.Module`, 21 SPM Targets in `Package.swift`)
1. `OpticalCore` — Pure domain models, `KroutonDomainIdentity`, 32 optical format recipes, `BurnClaimLedger`, `SpanManifest`. Zero external dependencies.
2. `DriveKit` — Optical hardware discovery & low-level I/O. **Strictly isolated:** never import UI or networking frameworks here.
3. `BurnKit` — `BurnSetScheduler`, `BusArbitrationState`, `BurnPowerAndBandwidthArbiter`, APFS CoW staging.
4. `ImageKit` — Hybrid ISO-9660 / Joliet / UDF / El Torito LBA planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256), `.cue/.bin` parser, SHA-256 sector inspector.
5. `AudioKit` — Red Book CD-DA 75 fps (2352 B/frame) engine, lock-free `CrossfadeParameterMailbox`, `SpliceOverlapMath`, CD-Text CRC-16, CUE compiler.
6. `VideoKit` — DVD-5/DVD-9/BD-25/BD-50 bitrate budgeting, menu-preserving DVD-9 -> DVD-5 shrink & `.IFO` relinking.
7. `RescueKit` — Bad-sector optical rescue copy engine & archival disc quality grading.
8. `LabelKit` — 300-DPI polar disc geometry & 1:1 vector PDF print sheet engine.
9. `NetworkSpool` — Client for **Krouton Server** (`krouton-server/`, Rust): KRSP v1 frames (`SpoolWireFrame`), Merkle manifests and the resumable `SpoolUploadSender`, pairing and session proofs (`SpoolPairing`), pinned mutual TLS (`SpoolTLS`, `SpoolServerConnection`), keys (`SpoolClientIdentity`), control messages (`SpoolControl`), and `SpoolRemoteNodeClient`. The server side of the protocol lives only in Rust. Depends only on `OpticalCore`.
10. `Persistence` — `SessionStore`, `RunLock` crash recovery, L10n catalog.
11. `KroutonApp` — macOS application target split into `Shell/` and `Features/` (plus `KroutonVerify` and 9 module test targets = 21 SPM targets total).

---

## 3. Non-Negotiable Code Style & Verification Gates (`krouton-verify`)
All code written or proposed for Krouton is automatically linted by **Suite 1, Suite 2, and Suite 18**:

- **Pure-SwiftUI Feature Gate (`Sources/KroutonApp/Features/`):**
  - Files under `Features/` must use **100% Pure SwiftUI**.
  - ** strictly banned in `Features/`:** `import AppKit`, `NSColor`, `NSView`, `NSImage`, `NSViewRepresentable`.
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
- **Swift 6 Strict Concurrency & Observation:**
  - All cross-isolation models must conform to `Sendable`.
  - UI state uses `@Observable` with leaf-granular sub-stores (`let` child store + `ReferenceWritableKeyPath`, Suite 24).
  - Workspace and rack views in `Features/` and `Shell/NavigationAndRack/` provide right-click `.contextMenu`s; `krouton-verify` Suite 3 requires at least 6 such view clusters, so do not remove them.

---
