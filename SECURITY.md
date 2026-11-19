# Security Policy

## NetworkSpool Threat Model
- **Zero-Trust LAN / Studio VPN:** Krouton's remote optical spooler (`_krouton-spool._tcp`, port `7420`) enforces strict numeric IP / CIDR validation (`SpoolEndpointPolicy`) on the actual connected endpoint to defeat DNS rebinding and `.local` query smuggling.
- **Mutual Authentication:** Remote spool sessions authenticate via commit-then-reveal numeric comparison pairing (`SpoolPairing` + TLS-PSK / `SpoolSessionProof`) or Keychain-backed P-256 Mutual TLS 1.3 public-key pinning (`SpoolTLS`).
- **No Shell Execution:** Suite 18 bans shell invocations (`/bin/sh`, `bash`, `zsh`, `popen`, `system`) across the entire codebase.
