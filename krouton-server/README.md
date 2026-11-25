# Krouton Server

Burn discs from Krouton on another computer. Put a burner on a Raspberry Pi, an old Mac, a Windows
PC, a Proxmox box or a NAS. Pair it with your Mac once, and pick it as the drive in Krouton's
burn sheet. Krouton uploads the image, the server burns and verifies it, and progress streams
back to the app.

```
Krouton (Mac)                                    Krouton Server (any OS, burner attached)
┌───────────────────────────┐  TLS 1.3, both     ┌──────────────────────────────────────────┐
│ NetworkSpool              │  keys pinned,      │ krouton-server   TLS, keys, CLI           │
│  KroutonServerClient      │◀── Ed25519 ───────▶│ server-core      sessions, staging, jobs, │
│  SpoolUploadSender        │  session proof     │                  drive workers, backends  │
│  SpoolTransferManifest    │  KRSP v1 frames    │ krsp             protocol (no deps)       │
└───────────────────────────┘                    └──────────────────────────────────────────┘
```

## Supported systems

| Burn box | Download | Burns with |
|---|---|---|
| Raspberry Pi 3/4/5, 64-bit Raspberry Pi OS | `linux-arm64` | `xorriso` |
| Raspberry Pi 2/3/4, 32-bit OS | `linux-armv7` | `xorriso` |
| Raspberry Pi Zero / 1 | `linux-armv6` | `xorriso` |
| Debian, Ubuntu, Proxmox VE, other x86-64 Linux, Synology, Unraid, TrueNAS SCALE | `linux-x86_64` | `xorriso` |
| Old 32-bit PCs running Linux | `linux-x86` | `xorriso` |
| Windows 10 and 11 (x64, x86, ARM64) | `windows-x64` / `-x86` / `-arm64` | IMAPI2 (built in) |
| macOS 12 or later (Intel or Apple Silicon) | `macos-x86_64` / `macos-arm64` | `hdiutil` (built in) |

The Linux builds are static (musl), so one binary runs on any distribution. Every pull request
builds all of them; download them from the **Krouton Server** workflow's artifacts, or build
locally with `cargo build --release -p krouton-server`.

## Set up

1. Copy the download for your box onto it and run its installer:

   | System | Command |
   |---|---|
   | Linux | `sudo deploy/linux/install.sh ./krouton-server` |
   | macOS | `deploy/macos/install.sh ./krouton-server` (as the logged-in user; turn on automatic login) |
   | Windows | `deploy\windows\install.ps1` in an elevated PowerShell |

   The installer sets up the service, creates the keys, and runs `krouton-server check`.
2. Pair your Mac. On the server run `krouton-server pair`. The Linux installer prints the
   exact command, which must run as the service user. In Krouton, open **Settings › Burn
   Servers › Add Server** and choose the server. Both screens show a 6-digit code; confirm it on
   both. That's it.
3. To try everything without a burner, set `backend = simulate` in `server.conf`.

| | Linux | macOS | Windows |
|---|---|---|---|
| Home (config, keys, pairings, spool) | `/var/lib/krouton-server` | `~/Library/Application Support/Krouton Server` | `C:\ProgramData\Krouton Server` |
| Logs | `journalctl -u krouton-server` | `~/Library/Logs/Krouton Server.log` | `krouton-server.log` in the home folder |

Commands: `init`, `run`, `pair`, `clients`, `unpair <name>`, `check`, `version`. All of them take
`--home <dir>`.

### `server.conf`

```text
name = Basement Burner
listen = 0.0.0.0:7420
backend = auto              # auto | macos | linux | windows | simulate
max_image_gib = 128
min_free_gib = 2            # keep this much free on the spool disk
allow_cgnat = false         # true to accept Tailscale / ZeroTier peers (100.64.0.0/10)
allow_range = 10.8.0.0/24   # extra trusted ranges, e.g. a WireGuard subnet (repeatable)
drive = /dev/sr0            # only use these drives (default: all); repeatable
```

Unknown keys are errors, so a typo cannot silently fall back to a default.

## What it does

* **Uploads resume.** The image travels as content-addressed extents (2048 sectors each,
  checked against a Merkle manifest). If the Wi-Fi drops, or either side restarts, only the
  missing extents are sent again. Every extent is on disk and journalled before it is
  acknowledged, so a power cut can never cause a corrupt extent to be burned.
* **Queues per drive.** Several Macs can share a server. Each drive burns its jobs in order, and
  every Mac sees its own jobs' positions in the queue.
* **Verifies.** On Linux and Windows the server reads the disc back and compares it with the image
  byte for byte. On macOS `hdiutil -verifyburn` does the same.
* **Survives restarts.** Queued jobs and half-finished uploads come back after a restart. A burn
  that was cut off is reported as failed, because the state of that disc is unknown.
* **Cleans up.** A burned image is deleted at once. Failed or abandoned uploads are kept for 48 hours
  (`keep_incomplete_hours`), so you can retry without uploading again.

Remote burning takes data images with 2048-byte sectors (ISO 9660 / UDF / hybrid: data discs,
DVD-Video and BD folders). Audio CDs and raw `.bin/.cue` images burn on the Mac's own drive.

## Security model

* **No CA, no passwords.** Each side has a P-256 TLS key and an Ed25519 identity. Pairing stores
  the other side's key pin (`SHA-256` of the X9.63 public key) and identity. After that, a
  connection must present the pinned TLS key, and each side signs the TLS 1.3 exporter with its
  identity. A stolen certificate without the key, or a session proof replayed from another
  connection, fails.
* **Pairing needs both people.** `krouton-server pair` opens a window of a few minutes. The
  server commits to its key before seeing the Mac's (commit-then-reveal), so an attacker in the
  middle gets one guess at the 6-digit code. Both the operator at the server and the person at
  the Mac must confirm that the codes match.
* **Local networks only by default.** Connections from public addresses are refused before TLS.
  VPN and Tailscale ranges can be opted in.
* **Isolation.** A job can only be seen, watched or cancelled by the Mac that submitted it. Other
  Macs get "unknown job" and cannot tell whether it exists.
* **Hardened input.** Frames are capped at 8 MiB, JSON at 256 KiB with bounded nesting, and
  identifiers are restricted to `[A-Za-z0-9._-]`. Log lines escape control characters. Burn
  tools get their arguments as separate parameters, never through a shell.
* **To revoke a Mac:** `krouton-server unpair "<name>"`, then restart the service.

## Protocol (KRSP v1)

Every message is a frame: a 64-byte big-endian header (`"KRSP"`, version, kind, flags, extent
index, first LBA, sector size, payload length, SHA-256 digest) followed by the payload. Extent
data, bitmaps and credit use binary frames. Control messages are JSON objects in kind-8 frames.
See `crates/krsp/src/control.rs` for the full message list and session sequence. The Swift side
lives in `Sources/NetworkSpool`. `Vectors/krsp-golden-v1.txt` pins both implementations byte for
byte, and is checked by `cargo test` and by `krouton-verify` Suite 29.

## Development

```sh
cargo test --workspace          # unit, golden-vector, end-to-end (TCP) and real-TLS tests
cargo clippy --workspace --all-targets
```

`krsp` and `server-core` have no third-party dependencies and contain every rule. The binary adds
only `rustls` and `ring` (TLS 1.3, Ed25519, X25519) and `rcgen` (the server's certificate).
