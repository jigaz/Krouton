# Burners, copies and the queue

## Destination cards

The right-hand column lists where the disc goes. Each destination is a card. **Add Output** (⇧⌘D) adds one; right-click a card for **Remove Destination Card**, **Eject** and **Execute Only This Destination**.

A burner card has:

- **Speed**. The fastest speed isn't always best. On cheap media, or for discs meant for old players, half the rated speed often gives fewer errors.
- **Verify**, which reads the disc back after burning and compares it with what was written. Leave it on unless you are short of time.
- **Simulate Burn**, which runs the whole burn with the laser at reading power. Use it to test a new drive or a new kind of blank without wasting one. Not every drive supports it.
- **Copies**, from 1 to 99.
- **Eject**, and for rewritable discs **Quick Erase** or **Full Erase**. A full erase takes as long as a burn but clears every sector.

Cards that don't burn:

- **Audio Rip**, under **Rip Audio CD**, rips the CD in the drive into the folder shown, one folder per album, as FLAC, Apple Lossless, WAV or AIFF; pick the format on the card. **Add Output** adds a card for another format, so one rip can make both FLAC and Apple Lossless files.
- **Video Extract**, under **Extract Video Disc**, reminds you that titles are chosen and extracted in the workspace.
- **Label Print Sheet** saves the label as a PNG and a PDF, and **Vector PDF Label** as a PDF only, into the folder shown on the card (Downloads for a new card), named after the disc title.
- A **Disc Image File** card saves the disc you're burning. To save the disc in the drive as an .iso, use **Duplicate Disc** in Copy.

## Several burners at once

Each connected burner gets a card under **Active Burners**. When you ask for more copies than there are burners, or burn a set of several discs, the rest wait in the **Waiting Burn Pool** below.

A burner only takes the next disc once a blank is actually in its tray and checked. A burner you haven't loaded never holds up the others.

The pool header switches between:

- **Auto-Assign (Next Free)**: whichever burner is ready first takes the next disc;
- **Ask / Manual**: you choose. Click **Promote** (↑) on a waiting disc to move it to the front, or **Assign ↑** to give it to a particular burner.

Turn on **Auto-Load Next Disc** in Settings › Burners & Network to make a hands-free duplicator: Krouton ejects each finished disc and starts the next as soon as you put a fresh blank in.

Several USB burners on one Mac compete for power and bandwidth. Krouton starts them 10 seconds apart, so their laser calibrations don't all draw power at once, and holds back the next drive while one that is already burning runs short of data.

## Old DVD players and game consoles

Some old DVD players and early game consoles only accept discs that say they are DVD-ROM. Some drives can mark DVD+R discs that way ("bitsetting"), but each maker uses its own unpublished command, and a wrong one can upset the drive's firmware, so Krouton doesn't send any. Use DVD-R discs for those players, or your drive maker's own utility.

## Leaving a disc open

**Disc › Leave Disc Open for More Sessions** burns without closing the disc, so another session can be added later. Depot entries that rely on this, such as a live CD that saves its settings back to its own disc, turn it on for you. Turn it off for discs meant for players or other computers: many can only read a closed disc.

## After the burn

When a burn ends, the burn report shows the drive, the disc, the speed it reached, how long it took and whether verification passed. **Disc › Copy Archival Quality Certificate** (⌥⌘C) copies a summary you can keep with the disc.

A real quality grade needs a C1/C2 error scan of the disc, which few drives can do. Without one, the certificate says the disc was **not measured**, rather than guessing.

## Watching a burn

**Window › Open Floating Phase Scope Telemetry** (⌥⌘P) shows a live view of the drive: write speed, buffer fill and progress. **Disc › Run Phase Scope Diagnostic Sweep** (⇧⌘P) runs a short test of the drive you have selected.

## Stopping

**Disc › Abort Active Operation** (⌘.) stops what Krouton is doing. Stopping during a burn usually leaves the disc unusable. A rewritable disc can be erased and used again.
