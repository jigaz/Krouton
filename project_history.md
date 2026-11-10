# Krouton Project History & Architecture Log

## Current Version: `v0.2.0-alpha.5` (Step 2C — Floating High-Detail Phase Scope Window)
* **Target OS:** macOS 26 (Tahoe) / Apple Silicon (`arm64`)
* **Domain:** [krouton.app](https://krouton.app)

### Phase Scope 3-Step Implementation Plan (COMPLETE)
* **Step 2A (`v0.2.0-alpha.3` — Completed):**
  1. Fixed `ContiguousArrayBuffer` out-of-range crash by using `UUID`-based destination card bindings.
  2. Built the textured, card-based **Disc Media Inspector Popover** with media-accurate disc icons (`CD-RW`, `CD-R`, `DVD-R`, `BD-R`, `M-DISC`, `DVD-RAM`), mounted volume/file scanning, and removed all non-clickable fake pills across the app.
  3. Implemented deterministic AppKit `NSWindow` launch inside `KroutonWindowManager`.
* **Step 2B (`v0.2.0-alpha.4` — Completed):**
  1. Added `DrivePhaseScopeTelemetry` per-drive dictionary (`driveTelemetry: [String: DrivePhaseScopeTelemetry]`) inside `DriveManager` so each connected optical burner tracks its own independent speed, spindle RPM, buffer fill, LBA sector cursor, and waveform samples.
  2. Embedded the auto-hiding **`InlineMiniPhaseScopeView`** inside each physical burner destination card: hidden when idle (`0 KB/s`), and automatically expands whenever that specific drive has active throughput (`> 0 KB/s`).
* **Step 2C (`v0.2.0-alpha.5` — Current Commit):**
  1. Added click-to-pop-out **Floating Phase Scope Window** (`NSWindow` per burner via `KroutonWindowManager.openFloatingPhaseScopeWindow`).
  2. Enforced single-graph-per-burner rule: opening a burner's floating Phase Scope window automatically hides its inline mini graph (`isFloatingWindowOpen = true`), and closing the floating window (or clicking **Dock Inline**) seamlessly returns the graph to the burner card.
  3. Built `FloatingPhaseScopeWindowView` with 5 modernized telemetry layers:
     - **Emerald Shaded Area + Curve:** Actual Write/Read Speed (`X` & `KB/s`)
     - **Dashed Cyan Curve:** Theoretical P-CAV Target Envelope (`4.2x -> 16.0x`)
     - **Amber/Gold Curve:** Spindle Motor Velocity (`RPM`)
     - **Purple Bottom Ribbon:** Hardware Drive Buffer Fill (`0–100%` BURN-Proof state)
     - **Red Vertical Playhead:** Live Radial LBA Cursor (`r = 24.0 mm -> 58.0 mm`) + 6-tile live hardware telemetry deck (`OPC Laser Power mW`, `Jitter %`, `Rotational Strategy`, `Radial Position`, `LBA Sector`, `Buffer State`).
