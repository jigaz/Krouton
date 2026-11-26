# Audio CDs

## Making an audio CD

Burning audio CDs isn't finished. You can lay out the disc as described below and check the result, but **Burn** doesn't write the audio CD yet: Krouton refuses, so no blank is wasted on a data disc of audio files. To make an audio CD today, burn a .cue/.bin image you already have with **Burn Disc Image**.

1. Choose **Red Book Audio CD (CD-DA)** in the Format Chooser (⌃⌘2).
2. Drag in audio files. WAV, AIFF, FLAC, ALAC, MP3 and AAC all work; Krouton converts each to CD audio (44.1 kHz, 16-bit stereo).
3. Drag tracks to reorder them. The capacity bar counts minutes: 74 on a 650 MB blank, 80 on a 700 MB blank.
4. Fill in the disc's title and artist. These become CD-Text, which many car stereos and CD players show.
5. Check it with **View › Inspect Compiled Red Book CUE Sheet** (⌃⌘U).

Krouton Server burns data discs and .iso images, not audio CDs.

## Gaps between tracks

Each track has a transition into the next:

- **2 sec Standard Pause**, the normal gap on commercial CDs;
- **1 sec Pause** or a custom pre-gap;
- **Gapless (0s)**, for live albums and DJ mixes that must flow without a break;
- **Crossfade**, where the end of one track fades into the start of the next.

## Shaping a crossfade

Choose **Crossfade** on a transition to open the **Track Montage Editor**. It shows the outgoing and incoming tracks over a 5-second window; **Zoom Out** widens it to 15 seconds.

Each fade is a curve. Hover near a quarter or three-quarter point of either curve and a faint diamond appears. Click to place a handle there, then drag it to change how that part of the fade rises or falls. Double-click a handle to remove it; **Reset** puts the curves back to the default. The **X-Fade** and **Tension** sliders set the length and overall shape.

Press **Preview** to hear the transition. Changes are audible as you drag.

The editor can float in its own window: **Window › Open Track Montage Editor Window** (⌥⌘M). Clicking the small waveform left in the track list brings that window to the front.

The montage header shows the tempo of both tracks and the difference between them, which helps match beat-driven music.

## CD-Text, ISRC and barcodes

CD-Text holds the disc title and artist and each track's title and artist. The format is old: it only stores Latin-1 characters (ISO-8859-1), at most about 60 characters per field, in no more than 255 small packs for the whole disc. The CD-Text counter warns you before you run out, and characters outside Latin-1 are flagged.

**ISRC** codes identify recordings (ISO 3901). **Auto-ISRC…** numbers a run of tracks for you from a prefix. **UPC/EAN** is the disc's barcode number, 12 or 13 digits.

Check the result with **View › Inspect Compiled Red Book CUE Sheet** (⌃⌘U). It shows the track table with every index position and the CD-Text that will be written.

## MP3 CDs for the car

**MP3 / FLAC Car Audio CD** burns your music files on a data CD, which most car stereos can play if the files are MP3 (many don't play FLAC). The files go on the disc as they are: the bit-rate, tag, artwork and file-name options in the workspace aren't applied yet, so convert and tag the files first if your stereo needs it.

**Blue Book CD-Extra** (audio tracks plus a data session) can't be made yet.

## Ripping a CD

1. Insert an audio CD and open the Audio CD Ripper (⌘5).
2. Choose **Disc › Scan Audio CD TOC & Lookup MusicBrainz** (⌥⌘R). Krouton reads the track list and fetches album and track names from MusicBrainz. Only the disc's ID is sent.
3. Pick a format: FLAC or ALAC to keep every bit, AAC for smaller files.
4. Choose **Disc › Rip Selected Audio CD Tracks** (⇧⌘R).

Tracks are saved in ~/Music/Krouton Rips, in a folder per album. The rip log records each track's CRC-32 and AccurateRip v1 checksums, so you can compare your rip with other people's rips of the same CD. A track with read errors is reported as failed; Krouton doesn't yet re-read damaged sectors to repair it.
