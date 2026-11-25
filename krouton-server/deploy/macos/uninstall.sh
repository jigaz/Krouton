#!/bin/sh
# Removes the LaunchAgent and binary. Keeps keys and pairings unless --purge.
set -eu
LABEL=app.krouton.server
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
sudo rm -f /usr/local/bin/krouton-server
if [ "${1:-}" = "--purge" ]; then
  rm -rf "$HOME/Library/Application Support/Krouton Server"
fi
echo "Krouton Server removed."
