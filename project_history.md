# Krouton Project History & Architecture Log

## Current Version: `v0.2.0-alpha.3` (Phase Scope & Multi-Burner Stabilization)
* **Target OS:** macOS 26 (Tahoe) / Apple Silicon (`arm64`)
* **Domain:** [krouton.app](https://krouton.app)

### Phase Scope 3-Step Implementation Plan
* **Step 2A (`v0.2.0-alpha.3` — Current Commit):**
  1. Fix `Swift/ContiguousArrayBuffer.swift:695: Fatal error: Index out of range` when removing a destination card by binding every destination card via its stable `UUID` (`id`) rather than raw array index `[index]`.
  2. Remove the global bottom graph from the central workspace while keeping the integrated **Disc Space Allocation** bar in the center workspace.
  3. Add deep optical media telemetry (`mediaManufacturer`, `dyeChemistry`, `bookStandard`, `sessionCount`, `usedBytes`, `mmssffTimecode`) to `OpticalDriveDevice` and make each burner card's green disc status pill clickable to open the **Disc Media Inspector Popover**.
* **Step 2B (`v0.2.0-alpha.4` — Next Commit):**
  1. Implement per-drive telemetry dictionary (`[String: PhaseScopeTelemetry]`) inside `DriveManager`.
  2. Embed an auto-hiding **Inline Mini Phase Scope** inside each physical burner card that automatically expands when that drive has active throughput (`> 0 KB/s`).
* **Step 2C (`v0.2.0-alpha.5` — Final Phase Scope Commit):**
  1. Add click-to-pop-out **Floating Phase Scope Window** (`NSWindow`) per burner (hiding the inline mini graph while the floating window is open).
  2. Render multi-layer high-detail curves: translucent Emerald Write Speed area, dashed Cyan Target P-CAV curve, Amber Spindle RPM curve, Purple Buffer Fill ribbon, and Red Radial LBA (`mm`) cursor.
