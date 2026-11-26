# Audio CDs

## Making an audio CD

1. Choose **Red Book Audio CD (CD-DA)** in the Format Chooser (⌃⌘2).
2. Drag in audio files. WAV, AIFF, FLAC, ALAC, MP3 and AAC all work; Krouton converts each to CD audio (44.1 kHz, 16-bit stereo).
3. Drag tracks to reorder them. The capacity bar counts minutes: 74 on a 650 MB blank, 80 on a 700 MB blank.
4. Fill in the disc's title and artist. These become CD-Text, which many car stereos and CD players show.
5. Check it with **View › Inspect Compiled Red Book CUE Sheet** (⌃⌘U).
6. Insert a blank CD-R and press **Burn** on a burner card.

Krouton renders the disc exactly as the editor plays it, pauses and crossfades included, and writes it in one pass (session-at-once) with the ISRCs, the UPC/EAN as the disc's catalog number, and CD-Text. Audio discs aren't read back afterwards, because drives can't read audio sectors at an exact position; play the disc to check it. A project longer than one CD has to be split into projects first.

A **Disc Image File** card saves the same disc as a .cue sheet and a .bin file instead, to burn later with **Burn Disc Image** or another app. Krouton Server burns data discs and disc images, not audio CDs: save a .cue/.bin, or burn on a drive connected to this Mac.

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

**MP3 / FLAC Car Audio CD** puts your music on a data CD that car stereos can play. Before burning, Krouton converts every audio file (folders are opened in name order) to MP3 at the chosen **Profile**: 320 or 192 kbps constant bit rate, or about 115 kbps variable for the most music per disc. The files are numbered in play order (**Zero-Pad Prefixes**), listed in PLAYLIST.M3U, and tagged ID3v2.3 with an ID3v1 copy, which older stereos need. **Strip Cover Art & Lyrics**, **Joint Stereo** and the **19 kHz Low-Pass Filter** are encoder settings. Only the audio goes on the disc, so no .DS_Store or ._ files reach it.

Converting needs ffmpeg, which you install separately (Homebrew: brew install ffmpeg). Choose **Files As They Are** to burn the files unconverted, still numbered and listed.

**DTS-CD (5.1)** burns DTS-encoded WAV files (44.1 kHz, 16-bit stereo, as DTS-CD files are made) exactly as they are, so a DTS decoder finds the surround stream. Krouton refuses any other file, and crossfades, because converting or mixing would destroy the stream. Pauses and gapless joins are fine.

**Blue Book CD-Extra** (also called Enhanced CD) puts the music in a first session, which every CD player plays, and files in a second session that computers open: videos, lyrics, artwork. Build the tracks as for an audio CD, then add the files under **Data Session** below the track list. Krouton adds the CDPLUS folder the Blue Book expects, burns both sessions in one go, and refuses before writing if the audio, the data and the second session's lead-in and lead-out (about 3 minutes) don't fit. The data session is written in Mode 1, which Macs and PCs read; the Blue Book prefers Mode 2, which only matters to a few old CD-ROM drives. CD-Extra is burned on a drive connected to this Mac; a .cue/.bin image holds only one session, so Krouton won't save one for it.

## Ripping a CD

1. Insert an audio CD and open the Audio CD Ripper (⌘5).
2. Choose **Disc › Scan Audio CD TOC & Lookup MusicBrainz** (⌥⌘R). Krouton reads the track list and fetches album and track names from MusicBrainz. Only the disc's ID is sent.
3. Pick a format: FLAC or ALAC keep every bit in less space; WAV and AIFF are uncompressed.
4. Choose **Disc › Rip Selected Audio CD Tracks** (⇧⌘R).

Tracks are saved in ~/Music/Krouton Rips, in a folder per album, named by the pattern in Settings › Ripping (01 - Artist - Title to start with; a / in the pattern makes folders), and tagged with the album, artist, track and the fields in **CD Info** (⌘I): composer, genre, year, disc number and compilation (Vorbis comments in FLAC, iTunes tags in ALAC, INFO chunks in WAV, text chunks in AIFF). The rip log records each track's CRC-32.

When every track of the disc is ripped and **Check With AccurateRip** is on, Krouton looks the disc up in the AccurateRip database (only the disc's ID is sent) and compares each track. The track list then shows **AR ✓** with the number of other rips that came out identical, or **AR ✗** when the database has the track but your rip differs, which usually means a scratch. macOS doesn't correct a drive's read offset, so Krouton finds your drive's offset from the database and reports it in the log. Krouton checks AccurateRip v1 checksums; a disc whose only entries are v2 won't match yet. A track with read errors is reported as failed; Krouton doesn't yet re-read damaged sectors to repair it.
