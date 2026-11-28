#!/usr/bin/env bash
# Runs Krouton Server with the drive-less `simulate` backend, for demos without a burner or discs.
#
#   Scripts/demo/start-demo-server.sh            build, set up the demo home, serve (Ctrl-C stops)
#   Scripts/demo/start-demo-server.sh --pair     in a second Terminal: let Krouton pair (once)
#   Scripts/demo/start-demo-server.sh --check    print the demo server's setup and drives
#
# Options (or the environment variables in brackets):
#   --home DIR      demo home: config, keys, pairings, spool [KROUTON_DEMO_HOME]
#                   default: ~/Library/Application Support/Krouton Server Demo (macOS),
#                            ~/.local/share/krouton-server-demo (Linux)
#   --port N        port to listen on, default 7420 [KROUTON_DEMO_PORT]
#   --listen ADDR   address to listen on, default 0.0.0.0 (this Mac and the LAN) [KROUTON_DEMO_LISTEN]
#   --drives N      simulated drives, 1-8, default 3 [KROUTON_DEMO_DRIVES]
#   --seconds N     length of one simulated burn incl. verify, 1-3600, default 40 [KROUTON_DEMO_SECONDS]
#   --name NAME     server name shown in Krouton, default "Demo Burner" [KROUTON_DEMO_NAME]
#   --no-build      use the existing build instead of running cargo
#
# The demo home is separate from a real Krouton Server's, so nothing here touches an installed
# server. To start over, quit the server and delete the demo home (see dev-notes/demo.md).
set -euo pipefail
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER_DIR="$ROOT/krouton-server"
BIN="$SERVER_DIR/target/release/krouton-server"

if [[ "$(uname -s)" == "Darwin" ]]; then
  DEFAULT_HOME="$HOME/Library/Application Support/Krouton Server Demo"
else
  DEFAULT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/krouton-server-demo"
fi
DEMO_HOME="${KROUTON_DEMO_HOME:-$DEFAULT_HOME}"
PORT="${KROUTON_DEMO_PORT:-7420}"
LISTEN="${KROUTON_DEMO_LISTEN:-0.0.0.0}"
DRIVES="${KROUTON_DEMO_DRIVES:-3}"
SECONDS_PER_BURN="${KROUTON_DEMO_SECONDS:-40}"
NAME="${KROUTON_DEMO_NAME:-Demo Burner}"
MODE=run
BUILD=1

die() { echo "start-demo-server: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pair) MODE=pair ;;
    --check) MODE=check ;;
    --no-build) BUILD=0 ;;
    --home) DEMO_HOME="${2:?--home needs a folder}"; shift ;;
    --port) PORT="${2:?--port needs a number}"; shift ;;
    --listen) LISTEN="${2:?--listen needs an address}"; shift ;;
    --drives) DRIVES="${2:?--drives needs a number}"; shift ;;
    --seconds) SECONDS_PER_BURN="${2:?--seconds needs a number}"; shift ;;
    --name) NAME="${2:?--name needs a name}"; shift ;;
    -h|--help) sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option $1 (try --help)" ;;
  esac
  shift
done

[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || die "--port must be 1-65535"
[[ "$DRIVES" =~ ^[0-9]+$ ]] && (( DRIVES >= 1 && DRIVES <= 8 )) || die "--drives must be 1-8"
[[ "$SECONDS_PER_BURN" =~ ^[0-9]+$ ]] && (( SECONDS_PER_BURN >= 1 && SECONDS_PER_BURN <= 3600 )) \
  || die "--seconds must be 1-3600"
# server.conf treats `#` as a comment and allows 1-64 characters.
[[ -n "$NAME" && "$NAME" != *"#"* && ${#NAME} -le 64 ]] || die "--name must be 1-64 characters without #"

# MARK: - Build

if (( BUILD )) && [[ "$MODE" == run ]]; then
  command -v cargo >/dev/null || die "cargo not found. Install Rust from https://rustup.rs, or pass --no-build."
  echo "Building krouton-server (release)…"
  (cd "$SERVER_DIR" && cargo build --release -p krouton-server)
fi
[[ -x "$BIN" ]] || die "$BIN is missing. Run without --no-build first."

# MARK: - Pair / check (talk to the demo home only)

if [[ "$MODE" == pair ]]; then
  [[ -f "$DEMO_HOME/server.conf" ]] || die "no demo server set up in $DEMO_HOME. Start it first (without --pair)."
  ADDRESS="127.0.0.1"
  PORT_IN_CONF="$(sed -n 's/^listen = .*:\([0-9]*\)$/\1/p' "$DEMO_HOME/server.conf" | head -n 1)"
  [[ -z "$PORT_IN_CONF" || "$PORT_IN_CONF" == 7420 ]] || ADDRESS="127.0.0.1:$PORT_IN_CONF"
  echo "In Krouton: Settings › Burners & Network › Krouton Servers: type $ADDRESS and click Pair by Address."
  echo "(The server's own hint below names an older menu; use the line above.)"
  echo
  exec "$BIN" --home "$DEMO_HOME" pair --minutes 10
fi
if [[ "$MODE" == check ]]; then
  exec "$BIN" --home "$DEMO_HOME" check
fi

# MARK: - Demo home and server.conf

mkdir -p "$DEMO_HOME"
cat > "$DEMO_HOME/server.conf" <<EOF
# Written by Scripts/demo/start-demo-server.sh on every start; edit its options instead.
name = $NAME
listen = $LISTEN:$PORT
# No burner needed: simulated drives upload, queue, "write", verify and eject like real ones.
backend = simulate
simulate_drives = $DRIVES
simulate_seconds = $SECONDS_PER_BURN
max_image_gib = 128
min_free_gib = 2
allow_cgnat = false
EOF

if [[ ! -f "$DEMO_HOME/identity.ed25519.pk8" ]]; then
  "$BIN" --home "$DEMO_HOME" init --backend simulate --name "$NAME" >/dev/null
  echo "Created demo server keys in $DEMO_HOME"
fi

# Refuse to start on a port something else (e.g. an installed Krouton Server) already uses.
if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
  die "port $PORT is already in use (an installed Krouton Server?). Stop it, or pass --port 7421."
fi

# MARK: - How to pair

ADDRESS="127.0.0.1"
[[ "$PORT" == 7420 ]] || ADDRESS="127.0.0.1:$PORT"
LAN_IP=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
fi
PAIRED="$("$BIN" --home "$DEMO_HOME" clients 2>/dev/null || true)"

cat <<EOF

  Krouton demo server "$NAME": $DRIVES simulated drive(s), $SECONDS_PER_BURN s per burn
  Home: $DEMO_HOME

EOF
if [[ "$PAIRED" == "No paired Macs"* || -z "$PAIRED" ]]; then
  cat <<EOF
  Not paired yet. Once, while this keeps running:
    1. Open a second Terminal and run:
         $ROOT/Scripts/demo/start-demo-server.sh --pair
    2. In Krouton: Settings › Burners & Network › Krouton Servers.
       Type  $ADDRESS  in the address field and click Pair by Address.
       ("$NAME" may also show up as a nearby server via Bonjour.)
    3. Check that both screens show the same 6-digit code, then answer y in Terminal
       and confirm in Krouton.
EOF
  if [[ -n "$LAN_IP" && "$LISTEN" == 0.0.0.0 ]]; then
    LAN_ADDRESS="$LAN_IP"
    [[ "$PORT" == 7420 ]] || LAN_ADDRESS="$LAN_IP:$PORT"
    echo "     (Another Mac on this network can pair with $LAN_ADDRESS.)"
  fi
else
  echo "  Paired Macs:"
  echo "$PAIRED" | sed 's/^/    /'
  echo "  In Krouton: Settings › Burners & Network, click Connect next to \"$NAME\"."
fi
cat <<EOF

  Then add a Krouton Server destination, pick "$NAME" and a drive, and click Burn Disc.
  Ctrl-C stops the server.

EOF

# MARK: - Serve

exec "$BIN" --home "$DEMO_HOME" run
