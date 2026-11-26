# Burning on another computer

Krouton Server is a small program you install on another computer that has a burner: a Raspberry Pi, a Linux box, a Proxmox host, a NAS, a Windows 10 or 11 PC, or an older Mac. After you pair it with this Mac once, its burners appear in Krouton like local ones.

It's handy when your Mac has no room for a USB burner, when the burner lives in another room, or when a few people share one good drive.

## How a network burn works

1. Krouton builds the disc image on your Mac.
2. It sends the image to the server over an encrypted connection. If the connection drops, the upload carries on from where it stopped.
3. The server checks every byte it received, then burns the disc and reads it back if **Verify** is on.
4. Progress shows on the destination card as it happens, and the burn report arrives at the end.

The laser never waits on your Wi-Fi: the whole image is on the server before the burn starts.

## Setting up the server

Follow the instructions at krouton.app/server for your kind of computer. In short: copy the server program to it and run the installer, which starts the service and runs a self-check. To test without a burner, set `backend = simulate` in the server's server.conf.

## Pairing

1. On the server, run `krouton-server pair`.
2. In Krouton, open **Settings** (⌘,) and go to **Burners & Network**. Under **Krouton Servers (Burners on Other Computers)**, nearby servers are listed under **Nearby, not paired**. Choose yours and click **Connect**. If it isn't listed, use **Pair by Address** and type its name or IP address, for example burner.local or 192.168.1.20.
3. Both screens show a six-digit code. If they match, click **The Codes Match** in Krouton and type y on the server. If they don't, click **The Codes Differ**: something between the two computers isn't what it seems, and nothing is saved.

Pairing happens once. From then on the two computers recognise each other by their keys. There are no passwords or accounts.

## Burning on the server

Add a destination with **Add Output** and choose **Network Server Burner**, then pick the server and one of its drives. Speed, Verify and Simulate work as they do for a local burner.

Krouton Server burns data discs and disc images. Audio CDs burn on a drive connected to this Mac.

## When it doesn't connect

- Both computers need to be on the same network. The server refuses connections from the internet. If you reach it through a VPN or Tailscale, turn on `allow_cgnat` (Tailscale and ZeroTier) or add an `allow_range` line in the server's server.conf.
- The first time, macOS asks whether Krouton may find devices on your local network. If you said no, turn it back on in System Settings › Privacy & Security › Local Network.
- A firewall on the server must let in TCP port 7420.
- On the server, `krouton-server check` reports problems with the drive, the burn tool, free space or the keys.
- **Save Log…** on the Krouton Servers card saves the connection log for a bug report.

To forget a server, click **Forget** next to it in Settings. To remove a Mac on the server side, run `krouton-server unpair` with the Mac's name; `krouton-server clients` lists them.
