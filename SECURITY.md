# Security Policy

## Krouton Server / NetworkSpool Threat Model
- **Local networks only:** the app checks the address a connection actually reached (`SpoolEndpointPolicy`, against DNS rebinding and `.local` smuggling), and the server refuses public source addresses before TLS. VPN and Tailscale ranges are opt-in on the server.
- **Mutual authentication without a CA:** each side has a P-256 TLS key and an Ed25519 identity. Pairing (`SpoolPairing`, commit-then-reveal, 6-digit code confirmed by both people) stores the other side's key pin and identity. Every session then requires the pinned TLS key on both sides plus Ed25519 signatures over the TLS 1.3 exporter (`SpoolSessionProof`), so a session proof cannot be replayed on another connection.
- **Server hardening:** frames capped at 8 MiB, JSON at 256 KiB with bounded depth; identifiers restricted to `[A-Za-z0-9._-]`; jobs visible only to the Mac that submitted them; burn tools receive arguments as separate parameters, never through a shell. See `krouton-server/README.md`.
- **No Shell Execution:** Suite 18 bans shell invocations (`/bin/sh`, `bash`, `zsh`, `popen`, `system`) across the entire codebase.
