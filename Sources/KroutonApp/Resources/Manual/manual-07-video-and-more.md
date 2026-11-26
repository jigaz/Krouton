# Video, copying and other formats

Parts of this chapter describe features that are still being built. Each section says where things stand.

## DVD-Video and Blu-ray

Choose **DVD-Video (VIDEO_TS)** (⌃⌘3) or a Blu-ray size (⌃⌘4 for a 25 GB single-layer disc) and add a disc that is already authored: a VIDEO_TS folder for DVD, a BDMV folder for Blu-ray. For DVD, Krouton writes the VIDEO_TS folder as an ISO 9660 + UDF 1.02 disc with the video files first and in the order players expect, as authored DVDs are laid out; add the folder that holds VIDEO_TS, or VIDEO_TS and AUDIO_TS themselves. Check one disc in your player before making more. For Blu-ray, Krouton writes the BDMV folder as a UDF 2.50 image (what Blu-ray players need) and burns that; add the folder that holds BDMV, or BDMV on its own. For 4K Ultra HD Blu-ray, choose **BDXL / UHD-BD** and burn the authored UHD BDMV folder to a 100 or 128 GB BD-R XL: UHD discs use the same UDF 2.50 file system. Krouton checks that the startup disk has room to build the image (as large as the disc) and that the blank in the drive holds it. Unprotected UHD discs on BD-R XL don't play in every UHD player, so try one disc first. **View › Inspect Video Bitrate Budget** (⌃⌘B) shows whether the video fits the disc at its bitrate.

Authoring menus and chapters from plain video files is not part of Krouton yet, so the workspace has no menu, video-standard or layer-break settings. A Krouton Server writes DVD-Video the same way.

## Copying a disc and fitting DVD-9 onto DVD-5

**Format › Copy, Rip & Rescue Workflows › Duplicate Disc / Fit-to-Disc DVD-9 Shrink** (⇧⌘K) copies the disc in the drive sector by sector into an .iso on your Desktop, so a bootable disc stays bootable and a Blu-ray keeps its UDF 2.50. It uses the rescue engine, so a scratch is retried and recorded rather than stopping the copy (see Rescue, below). Audio CDs can't be copied this way; rip them instead. A folder chosen with **Folder…** is copied file by file. When a dual-layer DVD doesn't fit a single-layer blank, Krouton re-encodes the video with ffmpeg, which you install separately (for example with Homebrew: brew install ffmpeg), and rewrites the disc's navigation files so the menus still point at the right places. This hasn't been checked on many players yet, so play the image in a player before burning a stack. Krouton doesn't remove copy protection, so it can only copy unprotected discs.

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

**AVCHD High-Definition** puts high-definition video on an ordinary DVD blank, laid out like a Blu-ray disc. Most Blu-ray players and the PlayStation 3, 4 and 5 play it; DVD players don't.

Drop video files (MP4, MOV, MKV and most others) on the deck, choose **DVD, 4.7 GB** or **Dual-layer DVD, 8.5 GB**, and click **Make Disc Image**. This needs ffmpeg (for example: brew install ffmpeg). Krouton converts each file to Blu-ray video (1080p, 1080i or 720p H.264, whichever is closest to the first file's frame rate) with Dolby Digital sound, at up to 18 Mbit/s, or lower so everything fits. About 30 minutes fit a single-layer DVD at full quality, and up to about two hours at lower rates; Krouton refuses more than the disc can hold at a watchable rate.

The files play one after another as a single title, with a chapter at the start of each and every five minutes. There's no menu. The finished image is saved in Movies › Krouton and opens in **Burn Disc Image**: put in a blank and burn. Converting takes about as long as the video plays, often longer.

Players differ, and this hasn't been tried on many yet: burn one disc and check it before making more.

## Retro consoles and old computers

The **Retro Console Optical Media** menu lists formats for the Wii, GameCube, PlayStation 1 and 2 and the original Xbox; Krouton also recognises Dreamcast and Saturn images. Drop an image you own on the deck and Krouton reads its header to tell you which console and game it is, its region, which blank to use, and what that console needs to play a burned disc. It then burns the image exactly as it is.

Consoles were built to refuse burned discs. Most need a modchip, a soft-mod or a loader such as Swiss (GameCube) or USB Loader GX (Wii), and several of those are in the Depot's **Console Homebrew** channel. Wii and GameCube discs are best played from a USB drive or SD card with those tools rather than burned. Some older consoles only read DVD-R; Krouton doesn't set the DVD-ROM book type on DVD+R (see Burners). Dreamcast .cdi and .gdi images can't be burned yet. Only make copies of games you own.

Settings › Format Chooser also lists formats for old computers: Mac OS 9 discs with classic HFS and strict 8.3 names for DOS and Windows 95. Mac OS 9 discs can't be made yet (Krouton refuses); DOS 8.3 discs are written as ISO 9660 Level 1 (see Data discs).
