# Krouton (`app.krouton`)

**Krouton** is a native macOS optical disc mastering, extraction, bad-sector rescue, and distributed burn-pool suite written in **Swift 6** with a 100% Pure-SwiftUI interface.

## Highlights
- **11-Module Clean Architecture (21 SPM Targets):** Strictly isolated hardware I/O (`DriveKit`), APFS copy-on-write burn staging (`BurnKit`), hybrid ISO-9660 / Joliet / UDF / El Torito LBA planning (`ImageKit`), 75 fps Red Book CD-DA & lock-free crossfade auditioning (`AudioKit`), DVD-9 to DVD-5 menu-preserving shrink (`VideoKit`), adaptive bad-sector recovery (`RescueKit`), 300-DPI vector disc labels (`LabelKit`), and zero-trust LAN/VPN optical spooling (`NetworkSpool`).
- **Deterministic Verification Harness (`krouton-verify`):** verification suites enforcing architectural boundaries, domain math, 500-frame telemetry fuzzing, loopback fault injection, and integration reachability ratchets in under 0.5 seconds.

## Requirements
- macOS 14.0 (Sonoma) or later
- Swift 6.0 / Xcode 16+

## Build, Test & Verify
```bash
# Build all targets
swift build

# Run unit tests
swift test

# Run the deterministic verification harness
swift run krouton-verify

# Launch Krouton
swift run Krouton
```

## Packaging a Release `.app` Bundle
```bash
./Scripts/bundle-app.sh
```
