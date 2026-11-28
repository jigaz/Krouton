#!/bin/sh
# Installs Krouton Server on macOS 12 or later (Intel or Apple Silicon).
# Run as the user who is logged in on the burn Mac (not with sudo): DiscRecording only burns
# inside a logged-in session, so the server runs as a LaunchAgent of that user. Turn on
# automatic login (System Settings > Users & Groups) so it starts after a reboot.
# Usage: ./install.sh [path/to/krouton-server]
set -eu

BIN="${1:-$(dirname "$0")/../../krouton-server}"
LABEL=app.krouton.server
DEST=/usr/local/bin/krouton-server
HOME_DIR="$HOME/Library/Application Support/Krouton Server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/Krouton Server.log"

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as the logged-in user, not with sudo (it asks for your password when needed)." >&2
  exit 1
fi
if [ ! -f "$BIN" ]; then
  echo "Cannot find the krouton-server binary at $BIN" >&2
  exit 1
fi

echo "==> Installing $DEST (needs your password)"
sudo mkdir -p /usr/local/bin
sudo install -m 0755 "$BIN" "$DEST"
# Downloaded binaries are quarantined; this one is verified by its SHA256SUMS instead.
sudo xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true

"$DEST" init

echo "==> Installing the LaunchAgent"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST</string><string>run</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PL
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

sleep 1
"$DEST" check || true

cat <<MSG

Krouton Server is running. Next, pair your Mac:

    krouton-server pair

Logs:    tail -f "$LOG"
Config:  $HOME_DIR/server.conf
         (then: launchctl kickstart -k gui/\$(id -u)/$LABEL)
macOS may ask to allow incoming connections the first time: choose Allow.
MSG
