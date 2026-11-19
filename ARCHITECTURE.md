# Krouton Architecture (`ARCHITECTURE.md`)

## 1. 11 Core Modules (`KroutonDomainIdentity.Module`)
1. **`OpticalCore`** — Domain models, 32 optical format recipes, `BurnClaimLedger`, `SpanManifest`, `KroutonDomainIdentity`. Zero external dependencies.
2. **`DriveKit`** — Optical hardware discovery, DiscRecording / IOKit arbitration, and media preflight.
3. **`BurnKit`** — `BurnSetScheduler`, `BurnSetStager` (APFS `fclonefileat` CoW staging), `BusArbitrationState`, `BurnPowerAndBandwidthArbiter`.
4. **`ImageKit`** — Hybrid ISO-9660 / Joliet / UDF / El Torito LBA planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256), `.cue/.bin` parser, SHA-256 sector inspector.
5. **`AudioKit`** — Red Book CD-DA 75 fps (2,352 B/frame) mastering, lock-free `CrossfadeParameterMailbox`, CD-Text CRC-16, CUE sheet compiler.
6. **`VideoKit`** — DVD-5/DVD-9/BD-25/BD-50 bitrate budgeting, menu-preserving DVD-9 -> DVD-5 shrink, `.IFO` sector relinking.
7. **`RescueKit`** — Bad-sector optical rescue copy engine and archival disc quality grading.
8. **`LabelKit`** — 300-DPI polar disc label geometry and 1:1 vector PDF print sheet generation.
9. **`NetworkSpool`** — Zero-trust LAN/VPN optical spooling (`KRSP` 64-byte wire framing, RFC 6962 Merkle manifests, resumable extent bitmaps, fenced drive leases, TLS-PSK & pinned mTLS 1.3).
10. **`Persistence`** — `SessionStore`, `RunLock` (`flock` crash recovery), localization catalog.
11. **`KroutonApp`** — Pure-SwiftUI macOS application (`Shell/` and `Features/`).

## 2. Verification Gates (`krouton-verify`)
- **Suite 1 & 2:** 11-module DAG isolation, Pure-SwiftUI Feature Gate (zero `AppKit`/`NSColor`/`NSImage`/`NSView` in `Features/`), 400-LOC view ceiling, 500-LOC non-view ceiling, 200-LOC function ceiling, canonical `// MARK: -` headers, and `+Role.swift` naming.
- **Suite 3–27:** Domain math, sector formatting, 500-frame telemetry fuzzing, APFS CoW staging, lock-free audio parameter mailbox, and SplitMix64 distributed spool fault recovery.
- **Suite 28:** Integration Reachability Ratchet (`PENDING_INTEGRATION.md`), ensuring unwired public library types can only shrink over time.
