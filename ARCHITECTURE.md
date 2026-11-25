# Krouton Architecture (`ARCHITECTURE.md`)

## 1. 11 Core Modules (`KroutonDomainIdentity.Module`)
1. **`OpticalCore`** — Domain models, 32 optical format recipes, `BurnClaimLedger`, `SpanManifest`, `KroutonDomainIdentity`. Zero external dependencies.
2. **`DriveKit`** — Optical hardware discovery, DiscRecording / IOKit arbitration, and media preflight.
3. **`BurnKit`** — `BurnSetScheduler` (multi-drive, with `BurnPowerAndBandwidthArbiter` staggering spin-ups), `BurnSetStager` (APFS `fclonefileat` CoW staging), `BusArbitrationState`.
4. **`ImageKit`** — Hybrid ISO-9660 / Joliet / UDF / El Torito LBA planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256), `.cue/.bin` parser, SHA-256 sector inspector.
5. **`AudioKit`** — Red Book CD-DA 75 fps (2,352 B/frame) mastering, lock-free `CrossfadeParameterMailbox`, CD-Text CRC-16, CUE sheet compiler.
6. **`VideoKit`** — DVD-5/DVD-9/BD-25/BD-50 bitrate budgeting, menu-preserving DVD-9 -> DVD-5 shrink, `.IFO` sector relinking.
7. **`RescueKit`** — Bad-sector optical rescue copy engine and archival disc quality grading.
8. **`LabelKit`** — 300-DPI polar disc label geometry and 1:1 vector PDF print sheet generation.
9. **`NetworkSpool`** — Client for Krouton Server: `KRSP` 64-byte wire framing, RFC 6962 Merkle manifests, resumable uploads, commit-then-reveal pairing, pinned mutual TLS 1.3 with Ed25519 session proofs, Bonjour discovery, and folder bundles (`SpoolBundleWriter`) for discs the server builds itself.
10. **`Persistence`** — `SessionStore`, `RunLock` (`flock` crash recovery), localization catalog.
11. **`KroutonApp`** — Pure-SwiftUI macOS application (`Shell/` and `Features/`).

## 2. Verification Gates (`krouton-verify`)
- **Suite 1 & 2:** 11-module DAG isolation, Pure-SwiftUI Feature Gate (zero `AppKit`/`NSColor`/`NSImage`/`NSView` in `Features/`), 400-LOC view ceiling, 500-LOC non-view ceiling, 200-LOC function ceiling, canonical `// MARK: -` headers, and `+Role.swift` naming.
- **Suite 3–27:** Domain math, sector formatting, 500-frame telemetry fuzzing, APFS CoW staging, lock-free audio parameter mailbox, and SplitMix64 distributed spool fault recovery.
- **Suite 28:** Integration Reachability Ratchet (`PENDING_INTEGRATION.md`), ensuring unwired public library types can only shrink over time.
- **Suite 29:** KRSP golden vectors, shared byte for byte with Krouton Server's Rust tests.
- **Suite 30:** `BurnSetScheduler` with scripted drives (retry only what failed, one disc per drive, staggered spin-up).
- **Suite 31:** Portable core. `OpticalCore`, `AudioKit`, `LabelKit`, `RescueKit`, `Persistence` and `NetworkSpool` depend only on each other and use no macOS-only framework or symbol outside `#if os(macOS)`, so an iPad app can share them. CI also compiles them for iPadOS (`ipados-portable-core` in `ci.yml`). `DriveKit`, `BurnKit`, `ImageKit` and `VideoKit` stay macOS-only: they drive burners and run `hdiutil`/`ffmpeg`. On iPad, burning goes through Krouton Server, which can build the disc from a folder (`burnFolder`).

## 3. Krouton Server (`krouton-server/`)
A headless Rust server that burns discs for Krouton on another computer (Raspberry Pi, Linux, Proxmox, NAS, Windows 10/11, macOS 12+). Three crates: `krsp` (protocol, no dependencies), `server-core` (sessions, staging, jobs, burn backends, no dependencies) and `krouton-server` (TLS via rustls/ring, CLI). See `krouton-server/README.md`.
