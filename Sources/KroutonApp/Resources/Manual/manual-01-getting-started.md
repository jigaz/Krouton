# Getting started

Krouton makes CDs, DVDs and Blu-ray discs on a Mac. It burns data discs that open on any computer, Blu-ray and DVD video you've already authored, and disc images you already have. It rips audio CDs, designs disc labels for printing, and can burn on a drive attached to another computer on your network.

## What you need

- A Mac with macOS 14 Sonoma or later, Apple silicon or Intel.
- An optical burner. Apple's own drives and almost any USB burner work. Krouton finds drives through macOS, so a drive that shows up in Finder shows up in Krouton.
- Blank discs that match the drive: CD-R or CD-RW for CDs, DVD±R for DVDs, BD-R for Blu-ray.

If the burner is plugged into a Raspberry Pi, a Linux box, a Windows PC or an older Mac instead, see **Burning on another computer**.

## Burn your first disc

1. Choose what you are making in the **Format Chooser** on the left. For files and folders, pick **Hybrid ISO-9660 + Joliet + UDF**. It opens on macOS, Windows and Linux.
2. Drag files and folders onto the middle of the window, or choose **File › Add Files or Disc Images…** (⇧⌘A).
3. Watch the **capacity bar** at the bottom of the middle column. It shows how full the disc is. If the files don't fit, Krouton plans a set of discs for you.
4. Put a blank disc in the burner. Its card appears on the right under **Active Burners**.
5. Choose **Disc › Execute Active Queue / Burn Now** (⌘B).

Krouton copies your files to a private staging area first, so a file you change or move during the burn can't spoil the disc. When the burn finishes, Krouton reads the disc back to check it if **Verify** is on, then ejects it.

## The window

The main window has three columns.

- **Format Chooser** (left). Every kind of disc Krouton can make, grouped by family: data, audio, video, retro consoles. Hide it with ⌃⌘S.
- **Mastering deck** (middle). What goes on the disc: files, tracks or a disc image, plus the settings for that kind of disc and the capacity bar.
- **Destination queue** (right). Where the result goes. A destination can be a burner on this Mac, a burner on a Krouton Server, a disc image file, an audio rip folder or a label print sheet. Hide it with ⌥⌘S.

The five workspaces have their own shortcuts: ⌘1 Burn Station, ⌘2 Disc Image Depot, ⌘3 Copy, Rip & Rescue, ⌘4 Polar Disc Label Studio and ⌘5 Audio CD Ripper.

## Projects

Krouton remembers what you were working on and restores it the next time you open it. To keep a disc layout for later, choose **File › Save Project (.krut)…** (⌘S). A project file stores the file list, track order and transitions, disc breaks and label. It refers to your files where they are; it does not copy them.

## What works today

Krouton is young. These parts are finished and tested on real drives:

- Data discs (hybrid ISO-9660, Joliet and UDF) and discs spanned across several blanks.
- Burning existing disc images (.iso, .cdr, .dmg, .cue/.bin, .toc), including bootable ones, and leaving a disc open for more sessions.
- The Depot: a checked list of downloadable discs, from old live CDs to console homebrew.
- Rescuing a damaged data disc into an image, with a ddrescue-style map so you can retry later.
- Saving a DVD's titles as MKV files (with ffmpeg) or as MPEG files.
- High-definition video on a DVD (AVCHD) that Blu-ray players play, from ordinary video files (with ffmpeg).
- Already-authored DVD-Video (a VIDEO_TS folder) and Blu-ray video (a BDMV folder, written as UDF 2.50).
- Identifying console disc images (Wii, GameCube, PlayStation, Dreamcast, Saturn, Xbox) and burning them as they are.
- Ripping audio CDs, with MusicBrainz lookup and per-track checksums.
- Audio CDs burned from the Audio CD editor, pauses, crossfades, ISRCs and CD-Text included, or saved as .cue/.bin.
- MP3 CDs converted for the car (with ffmpeg), and M-DISC data discs with PAR2 recovery files (with par2).
- Disc labels exported as 1:1 PDF or 300-DPI PNG.
- Burning on a Krouton Server.
- The `krouton` command-line tool and Shortcuts actions.

These are still being built. Their screens are there so you can see where Krouton is going, but they may not do the whole job yet. Where burning would give the wrong kind of disc, Krouton refuses and says why instead of writing anything:

- Audio CDs on many players and drives. Krouton burns them session-at-once with CD-Text, but this hasn't been tried on many drives yet; burn one and play it before making more.
- CD-Extra, DVD-Audio, Video CD and Photo CD discs can't be made yet.
- Authoring DVD or Blu-ray menus from plain video files.
- Shrinking a dual-layer DVD onto a single-layer disc while keeping its menus. It hasn't been checked on many players yet.
- AVCHD discs on players: the format follows the Blu-ray specification and libbluray reads it, but it hasn't been checked on many players yet.
- Quality grading of a burned disc. Without a C1/C2 error scan the certificate says the disc was not measured.
- Burning .cdi and .gdi images (Dreamcast) and compressed images (.wbfs, .rvz, .chd). Krouton names these and explains how to convert them, but can't burn them yet.

## Getting help

- Choose **Help › Interactive Guided Tutorials** for a tour that highlights the controls on screen.
- Every chapter of this manual is also online at krouton.app/manual.
- **Help › Report a Problem** opens the project's issue tracker on GitHub.
- **Help › Report a Drive** explains how to share what your burner can do, so people with the same model know what to expect.
