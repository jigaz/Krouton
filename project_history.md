# Krouton Project History & Architecture Log

## Current Version: `v0.2.0-alpha.4` (Step 2B — Per-Drive Inline Mini Phase Scope)
* **Target OS:** macOS 26 (Tahoe) / Apple Silicon (`arm64`)
* **Domain:** [krouton.app](https://krouton.app)

### Phase Scope 3-Step Implementation Plan
* **Step 2A (`v0.2.0-alpha.3` — Completed):**
  1. Fixed `ContiguousArrayBuffer` out-of-range crash by using `UUID`-based destination card bindings.
  2. Built the textured, card-based **Disc Media Inspector Popover** with media-accurate disc icons (`CD-RW`, `CD-R`, `DVD-R`, `BD-R`, `M-DISC`, `DVD-RAM`), mounted volume/file scanning, and removed all non-clickable fake pills across the app.
  3. Implemented deterministic AppKit `NSWindow` launch inside `KroutonWindowManager`.
* **Step 2B (`v0.2.0-alpha.4` — Current Commit):**
  1. Added `DrivePhaseScopeTelemetry` per-drive dictionary (`driveTelemetry: [String: DrivePhaseScopeTelemetry]`) inside `DriveManager` so each connected optical burner tracks its own independent speed, spindle RPM, buffer fill, LBA sector cursor, and waveform samples.
  2. Added a per-drive `Timer` Registry (`driveTimers: [String: Timer]`) so simultaneous multi-drive burns update each burner's telemetry independently.
  3. Embedded the auto-hiding **`InlineMiniPhaseScopeView`** inside each physical burner destination card: hidden when idle (`0 KB/s`), and automatically expands with a live CRT grid, Emerald Write Speed curve, Amber Spindle RPM curve, and Red LBA cursor whenever that specific drive has active throughput (`> 0 KB/s`).
  4. Added a **"Test Scope"** pill button inside each burner card so you can test-fire a 6-second simulated P-CAV laser telemetry sweep on any drive without burning a disc.
* **Step 2C (`v0.2.0-alpha.5` — Next Commit):**
  1. Clicking the inline mini Phase Scope pops out a dedicated, resizable **Floating Phase Scope Window** (`NSWindow`) for that burner (automatically hiding the inline mini graph while its floating window is open).
  2. Render multi-layer high-detail curves: translucent Emerald Write Speed area, dashed Cyan Target P-CAV curve, Amber Spindle RPM curve, Purple Buffer Fill ribbon, and Red Radial LBA (`r = 24.0 mm -> 58.0 mm`) cursor.
