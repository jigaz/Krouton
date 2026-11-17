# Krouton Architecture & Verification Gate

Krouton is structured as a strict 11-target Swift 6 package with hardware isolation and an automated 22-suite architectural verification gate (krouton-verify).

## Targets
1. OpticalCore: Domain models, LBA math, Red Book 75-fps math, KroutonSpanningDiscMedium.
2. DriveKit: Hardware abstraction isolating IOKit, DiscRecording, DiskArbitration, and hdiutil.
3. ImageKit: Hybrid ISO-9660/UDF/El Torito LBA planner, CUE/BIN extractor, SHA-256 & hex inspector.
4. AudioKit: Red Book CUE compiler, 18B CD-TEXT CRC-16 encoder, equal-power crossfade DSP.
5. VideoKit: Optical bitrate budgeter, DVD-9 to DVD-5 shrink engine, IFO relinker, AVCHD muxer.
6. BurnKit: DiscSpanningEngine, frozen BurnSet state machine, single-read stager.
7. RescueKit: Bad-sector optical rescue engine and archival disc quality grader.
8. LabelKit: Polar 300-DPI disc geometry engine and 1:1 vector PDF print sheet generator.
9. NetworkSpool: Port 7420 remote optical burn server and spool telemetry.
10. Persistence: SessionStore, RunLock crash recovery, and security-scoped bookmark vault.
11. KroutonApp: SwiftUI macOS shell, AppIntents Shortcuts provider, and KroutonCLIRunner.
