#!/bin/sh
# Removes the service and binary. Keeps /var/lib/krouton-server (keys, pairings) unless --purge.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "Run this with sudo." >&2; exit 1; }
systemctl disable --now krouton-server 2>/dev/null || true
rm -f /etc/systemd/system/krouton-server.service /usr/local/bin/krouton-server
systemctl daemon-reload
if [ "${1:-}" = "--purge" ]; then
  rm -rf /var/lib/krouton-server
  userdel krouton 2>/dev/null || true
fi
echo "Krouton Server removed."
