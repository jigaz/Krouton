# Video, copying and other formats

Parts of this chapter describe features that are still being built. Each section says where things stand.

## DVD-Video and Blu-ray

Choose **DVD-Video (VIDEO_TS)** (⌃⌘3) or a Blu-ray size (⌃⌘4 for a 25 GB single-layer disc) and add a disc that is already authored: a VIDEO_TS folder for DVD, a BDMV folder for Blu-ray. Krouton writes it with the file system those players expect. **View › Inspect Video Bitrate Budget** (⌃⌘B) shows whether the video fits the disc at its bitrate.

Authoring menus and chapters from plain video files is not part of Krouton yet.

## Copying a disc and fitting DVD-9 onto DVD-5

**Format › Copy, Rip & Rescue Workflows › Duplicate Disc / Fit-to-Disc DVD-9 Shrink** (⇧⌘K) copies a disc into an .iso on your Desktop. When a dual-layer DVD doesn't fit a single-layer blank, Krouton re-encodes the video with ffmpeg, which you install separately (for example with Homebrew: brew install ffmpeg), and rewrites the disc's navigation files so the menus still point at the right places. This hasn't been checked on many players yet, so play the image in a player before burning a stack. Krouton doesn't remove copy protection, so it can only copy unprotected discs.

## Extracting video

**Video Disc Extractor** (⇧⌘V) saves the titles you tick on a DVD to ~/Movies/Krouton Extracts. Choose:

- **MKV, all audio and subtitles**: each title becomes one .mkv file with every audio and subtitle track, copied without re-encoding. This needs ffmpeg.
- **MPEG file, copied as it is**: each title's pieces are joined into one .mpg file. This works without ffmpeg. If you choose MKV and ffmpeg isn't installed, Krouton falls back to this and tells you.

Unprotected discs only: Krouton doesn't remove copy protection.

## Rescue

**Format › Copy, Rip & Rescue Workflows › Optical Bad-Sector Rescue & Recovery** (⌥⌘D) copies a damaged CD-ROM, DVD or Blu-ray data disc into an .iso. Krouton copies everything that reads easily first, skipping ahead past trouble, then goes back to the damaged areas one sector at a time. Sectors that never read are saved as zeros.

Beside the image, Krouton keeps a map file (name.iso.map) in GNU ddrescue's format, saved every few seconds. The bar under the controls shows the disc as it goes: what's copied, what's still to try and what's bad. To try again, clean the disc or move it to another drive and start a rescue with the same name in the same folder: Krouton reads only the sectors still missing. Raising **Retry each bad sector** spends longer on stubborn sectors. You can also hand the image and map to ddrescue itself.

Krouton unmounts the disc while it works so it has the drive to itself. For a scratched audio CD, use **Rip Audio CD** instead.

## AVCHD

**AVCHD High-Definition** puts high-definition camcorder video on a DVD blank so some Blu-ray players can play it. This is in development and waits for testing on real players; Krouton doesn't write AVCHD discs yet.

## Retro consoles and old computers

The **Retro Console Optical Media** menu lists formats for the Wii, GameCube, PlayStation 1 and 2 and the original Xbox; Krouton also recognises Dreamcast and Saturn images. Drop an image you own on the deck and Krouton reads its header to tell you which console and game it is, its region, which blank to use, and what that console needs to play a burned disc. It then burns the image exactly as it is.

Consoles were built to refuse burned discs. Most need a modchip, a soft-mod or a loader such as Swiss (GameCube) or USB Loader GX (Wii), and several of those are in the Depot's **Console Homebrew** channel. Wii and GameCube discs are best played from a USB drive or SD card with those tools rather than burned. Some older consoles read DVD+R more reliably with the DVD-ROM book type set (see Burners). Dreamcast .cdi and .gdi images can't be burned yet. Only make copies of games you own.

The Data menu also has formats for old computers: Mac OS 9 discs with classic HFS and an Apple Partition Map, and strict 8.3 file names for DOS and Windows 95. Test such a disc on the machine it is for before burning a stack.
