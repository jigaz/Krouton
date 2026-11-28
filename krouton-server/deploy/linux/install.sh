#!/bin/sh
# Installs Krouton Server as a systemd service on Debian, Ubuntu, Raspberry Pi OS or Proxmox VE.
# Usage: sudo ./install.sh [path/to/krouton-server]
set -eu

BIN="${1:-$(dirname "$0")/../../krouton-server}"
HOME_DIR=/var/lib/krouton-server
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo." >&2
  exit 1
fi
if [ ! -x "$BIN" ]; then
  echo "Cannot find the krouton-server binary at $BIN" >&2
  exit 1
fi

echo "==> Installing burn and discovery tools"
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq xorriso avahi-utils
else
  echo "    apt-get not found: install xorriso (and avahi-utils for Bonjour) with your package manager."
fi

echo "==> Creating the krouton service user"
if ! id krouton >/dev/null 2>&1; then
  useradd --system --home-dir "$HOME_DIR" --shell /usr/sbin/nologin krouton
fi
getent group cdrom >/dev/null 2>&1 && usermod -aG cdrom krouton

echo "==> Installing /usr/local/bin/krouton-server"
install -m 0755 "$BIN" /usr/local/bin/krouton-server
install -d -m 0700 -o krouton -g krouton "$HOME_DIR"
sudo -u krouton KROUTON_SERVER_HOME="$HOME_DIR" /usr/local/bin/krouton-server init

echo "==> Installing the systemd service"
install -m 0644 "$HERE/krouton-server.service" /etc/systemd/system/krouton-server.service
systemctl daemon-reload
systemctl enable --now krouton-server

sleep 1
sudo -u krouton KROUTON_SERVER_HOME="$HOME_DIR" /usr/local/bin/krouton-server check || true

cat <<MSG

Krouton Server is running. Next, pair your Mac:

    sudo -u krouton KROUTON_SERVER_HOME=$HOME_DIR krouton-server pair

Logs:    journalctl -u krouton-server -f
Config:  $HOME_DIR/server.conf   (then: sudo systemctl restart krouton-server)

Proxmox VE: pass the USB burner through to the VM or container that runs this
(for LXC also allow the /dev/sr* and /dev/sg* devices), or install directly on the host.
MSG
