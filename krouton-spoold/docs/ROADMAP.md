# krouton-spoold Roadmap

How the 32 consultation questions map to milestones. Each milestone ends with `spoold-verify` green and new checks for everything it adds.

## Milestone 1: protocol core & verification ✅ (this round)

| Question | Status | Where |
|---|---|---|
| Q1 Workspace layout & DAG | ✅ | `Cargo.toml` (the planned crates are drawn in the header comment) |
| Q5 Byte-exact frames, manifest, bitmap, journal, pipeline, leases | ✅ | `spoold-proto` |
| Q9 Endpoint policy (mapped IPv6, NAT64/6to4/Teredo, CGNAT opt-in, studio CIDRs) | ✅ | `spoold-proto::endpoint` |
| Q21 Terminal-sticky conflation (the pure part) | ✅ | `spoold-proto::telemetry` |
| Q30 Deterministic harness | ✅ | `spoold-verify` (99 checks, determinism gate, mutation-tested) |
| Q31 Cross-language golden vectors | ✅ | `vectors/` + Python generator + Swift Suite 29 |
| Q6/Q7 Pairing transcript & session proof | ✅ code, ⏳ first compile on your Mac | `spoold-crypto` |

## Milestone 2: talk to the Mac app (macOS first)

**Prerequisite:** the contract decisions D1–D4 in the review.

| Question | Plan |
|---|---|
| Q6 mTLS | `spoold-net`: rustls 0.23 server with a custom `ClientCertVerifier` that **still verifies the TLS 1.3 handshake signature** (via the crypto provider) and then checks `SHA256(X9.63 key)` against the pin store; `export_keying_material` → session proof |
| Q4 Runtime | `tokio` `current_thread` for networking; one dedicated OS thread per drive; bounded channels between them |
| Q20 mDNS | `mdns-sd` (pure Rust, works without Avahi/Bonjour services); advertise once per interface set, debounced re-announce |
| Q7 Headless pairing | `krouton-spoold pair` prints the 6-digit code + a QR of `krouton-pair://<nodeID>/<128-bit token>`; the token replaces the code check |
| Q8 Key storage | macOS: `/Library/Application Support/app.krouton/spoold/` with 0600 permissions, owned by a dedicated `_kroutonspool` user |
| Q16–Q17 Storage (macOS) | `spoold-store`: `F_PREALLOCATE` + `F_BARRIERFSYNC` + journal, ported from `SpoolExtentStore.swift` |

## Milestone 3: first real burn (an older Mac, macOS 12+)

| Question | Plan |
|---|---|
| Q10 HAL trait | `spoold-hal::OpticalDriveHal`. CDB builders are pure functions, tested in `spoold-verify` |
| Q13 macOS backend | DiscRecording (via `objc2`) for standard burns. IOKit `SCSITaskDeviceInterface` only for rescue reads. `DADiskClaim` so Finder never mounts the target |
| Q14 Hot-plug | IOKit matching notifications; no polling |
| Q19 Rolling window | Contiguous-committed watermark (`AtomicU64` + notify) between the network writer and the drive reader |
| Q26–Q27 Service | `launchd` daemon running as an unprivileged user |

## Milestone 4: Linux, Windows, packaging

Q2, Q3, Q11, Q12, Q15, Q16 (Pi SD-card detection), Q18, Q22–Q25, Q28, Q29, Q32. The HAL trait and the verify harness are already platform-neutral, so these are new backends, not redesigns.
