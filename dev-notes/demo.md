# Demo kit: burning without a burner

Shows real end-to-end burns from Krouton on a Mac with no drive and no discs. Krouton Server runs
on the same Mac with its `simulate` backend: Krouton pairs with it, builds the image, uploads it,
and the server queues, "writes", verifies and ejects it with live progress, exactly as a real
server would. Only the drive is pretend.

| File | What it does |
|---|---|
| `Scripts/demo/start-demo-server.sh` | builds `krouton-server`, sets up a separate demo home, writes its `server.conf` (`backend = simulate`, 3 drives, 40 s per burn, name "Demo Burner") and runs the server in the foreground |
| `Scripts/demo/make-demo-files.py` | writes ~39 MB of original sample content: 5 generated PNG pictures, 5 synthesised WAV tracks (44.1 kHz 16-bit stereo, 2:40 in all), text, Markdown, a CSV and nested folders. Same bytes on every run |

## Commands (on the Mac, from the repository root)

```sh
python3 -I Scripts/demo/make-demo-files.py      # ~/Desktop/Krouton Demo Files (--out DIR to change)
Scripts/demo/start-demo-server.sh               # needs Rust (rustup.rs); Ctrl-C stops it
```

The server script takes `--drives 1-8`, `--seconds 1-3600` (one burn, verify included),
`--name`, `--port`, `--home` and `--no-build`; `--help` lists them. `--check` prints the demo
server's setup and drives.

## Pairing (once)

1. Leave `start-demo-server.sh` running. In a second Terminal run
   `Scripts/demo/start-demo-server.sh --pair` (opens a 10-minute pairing window).
2. In Krouton: **Settings › Burners & Network › Krouton Servers**, type `127.0.0.1` in the address
   field and click **Pair by Address** (`127.0.0.1:PORT` if you passed `--port`). The server
   may also appear under nearby servers through Bonjour, but loopback works even if the macOS
   firewall blocks incoming connections.
3. Both screens show a 6-digit code: answer `y` in Terminal, then confirm in Krouton.

Pairing survives restarts. On later runs click **Connect** next to "Demo Burner" in the same
settings pane. To burn: add a Krouton Server destination, choose "Demo Burner" and a drive, and
click **Burn Disc**. The `pair` command's own hint names an older menu path
("Burn Servers › Add Server"); follow the steps above instead.

## Reset

1. Stop the server (Ctrl-C) and delete the demo home:
   `rm -rf ~/Library/Application\ Support/Krouton\ Server\ Demo`.
2. In Krouton: **Settings › Storage & Reset › Forget All Servers** (or **Forget** next to
   "Demo Burner"), because the next demo home has new keys.

The demo home is separate from an installed Krouton Server's (`~/Library/Application
Support/Krouton Server`), which it never touches. If an installed server already listens on
port 7420 the script stops and says so; pass `--port 7421`.

## Known limits

- Simulated drives always report **blank** media, write every disc family (CD, DVD, BD) and
  accept any image size. They are named "Simulated BD-RE Drive N".
- A burn takes `--seconds` regardless of image size: 80 % "writing" (at the chosen speed, 8x if
  none), then 20 % "verifying" when verify is on. Nothing is written or read back; the server
  only checks that the uploaded image is really there and complete. Cancel works.
- Everything before the drive is real: pairing and pinned TLS, image building on the Mac,
  the resumable upload, the per-drive queue, folder jobs (DVD-Video is sent as files and
  mastered on the server; the simulated master writes a placeholder image of the right size),
  telemetry and the completion report. The uploaded image is deleted after the "burn".
- Audio CDs don't burn on any Krouton Server (Krouton refuses before upload). With the WAVs, show
  an audio CD project and save it as a disc image (.cue/.bin), or put them on a data disc.
- Eject does nothing. Uploads over loopback are near-instant, so the upload phase is brief.
- On Linux the script works too (home `~/.local/share/krouton-server-demo`), but there is no
  Krouton app there; that is how the script was checked.
