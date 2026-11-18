# CLAUDE.md — Krouton (`app.krouton`)

This file provides canonical architectural context, build/verification commands, and strict source-hygiene invariants for Claude and peer AI agents working on **Krouton**.

## 1. Essential Commands
- **Build All Targets:** `swift build`
- **Run Unit Tests:** `swift test`
- **Run Deterministic Verification Harness (27 Suites / 476 Assertions / 5,152 Rules):** `swift run krouton-verify`
- **Launch macOS App:** `swift run Krouton`

> **Mandatory Verification Rule:** Every code change or architectural proposal MUST pass `swift test && swift run krouton-verify` with zero warnings and zero failures.

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
9. `NetworkSpool` — Zero-trust LAN/VPN optical spooling (`SpoolWireFrame`, `SpoolTransferManifest`, `SpoolExtentPipeline`, `SpoolExtentStore`, `DriveLeaseTable`, `SpoolCutoverPolicy`, `SpoolEndpointPolicy`, `SpoolPairing`, `SpoolSecureTransport`, `SpoolPathRanking`, `SpoolTelemetryConflator`). Depends only on `OpticalCore`.
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
- **Zero Shell-Injection / Zero Subprocess Networking (Suite 18):**
  - Never use `Process`, `NSTask`, `/bin/sh`, `curl`, `rsync`, `nc`, or `ssh`.
  - All networking and IPC must use native Apple frameworks (`Network.framework`, `URLSession`, `CryptoKit`).
- **Swift 6 Strict Concurrency & Observation:**
  - All cross-isolation models must conform to `Sendable`.
  - UI state uses `@Observable` with leaf-granular sub-stores (`let` child store + `ReferenceWritableKeyPath`, Suite 24).
  - Never use `.contextMenu` inside `Features/` or `Shell/NavigationAndRack/` where custom popover/pill controls are mandated.

---

## 4. Current Consultation Task (Networking Strategy Q1–Q10)
When reviewing `Krouton_Networking_Consultation.zip`:
1. Start with this `CLAUDE.md` and `00_KROUTON_NETWORKING_CONTEXT.md`.
2. Answer all 10 architectural questions in `01_NETWORKING_STRATEGY_QUESTIONS.md` (`Q1`–`Q10`).
3. Cross-reference the real production implementations in `ReferenceSources/` (`SpoolLANSecurityEngine`, `BurnClaimLedger`, `VerifyHarness+PeerAgentSynthesisSuites.swift`, etc.).
4. Provide complete, deterministic Swift 6 code for **Suite 27** (`Q10`) ready to drop into `Sources/KroutonVerify/`.
