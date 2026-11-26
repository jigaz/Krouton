# Audio CDs

## Making an audio CD

1. Choose **Red Book Audio CD (CD-DA)** in the Format Chooser (⌃⌘2).
2. Drag in audio files. WAV, AIFF, FLAC, ALAC, MP3 and AAC all work; Krouton converts each to CD audio (44.1 kHz, 16-bit stereo).
3. Drag tracks to reorder them. The capacity bar counts minutes: 74 on a 650 MB blank, 80 on a 700 MB blank.
4. Fill in the disc's title and artist. These become CD-Text, which many car stereos and CD players show.
5. Burn with ⌘B.

Audio CDs burn on a drive connected to this Mac. Krouton Server burns data discs only.

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

**MP3 / FLAC Car Audio CD** fits many hours of music on one data CD that most car stereos can play. Choose 320 kbps for quality or 192 kbps to fit more. Krouton can force ID3v2.3 tags, which older stereos need, strip cover art and lyrics to save space, and enforce short upper-case file names.

**Blue Book CD-Extra** puts audio tracks first, which a CD player plays, and a data session after them, which a computer opens.

## Ripping a CD

1. Insert an audio CD and open the Audio CD Ripper (⌘5).
2. Choose **Disc › Scan Audio CD TOC & Lookup MusicBrainz** (⌥⌘R). Krouton reads the track list and fetches album and track names from MusicBrainz. Only the disc's ID is sent.
3. Pick a format: FLAC or ALAC to keep every bit, AAC for smaller files.
4. Choose **Disc › Rip Selected Audio CD Tracks** (⇧⌘R).

Tracks are saved in ~/Music/Krouton Rips, in a folder per album. The rip log records each track's CRC-32 and AccurateRip v1 checksums, so you can compare your rip with other people's rips of the same CD. A track with read errors is reported as failed; Krouton doesn't yet re-read damaged sectors to repair it.
