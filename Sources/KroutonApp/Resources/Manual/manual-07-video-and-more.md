# Video, copying and other formats

Parts of this chapter describe features that are still being built. Each section says where things stand.

## DVD-Video and Blu-ray

Choose **DVD-Video (VIDEO_TS)** (⌃⌘3) or a Blu-ray size (⌃⌘4 for a 25 GB single-layer disc) and add a disc that is already authored: a VIDEO_TS folder for DVD, a BDMV folder for Blu-ray. Krouton writes it with the file system those players expect. **View › Inspect Video Bitrate Budget** (⌃⌘B) shows whether the video fits the disc at its bitrate.

Authoring menus and chapters from plain video files is not part of Krouton yet.

## Copying a disc and fitting DVD-9 onto DVD-5

**Format › Copy, Rip & Rescue Workflows › Duplicate Disc / Fit-to-Disc DVD-9 Shrink** (⇧⌘K) is meant to copy a dual-layer DVD onto a cheaper single-layer blank while keeping its menus. The shrink re-encodes the video with ffmpeg, which you install separately (for example with Homebrew: brew install ffmpeg). This workflow is still being finished; check the result in a player before relying on it.

## Extracting video

**Video Disc Extractor** (⇧⌘V) will save a disc's titles as video files. It is not finished yet: running it reports that and writes nothing.

## Rescue

**Optical Bad-Sector Rescue & Recovery** (⌥⌘D) will copy everything readable from a damaged disc and keep retrying the bad areas. Today a read error is reported rather than repaired. Until rescue is ready, a dedicated tool such as ddrescue is the better choice for a disc that matters.

## AVCHD

**AVCHD High-Definition** puts high-definition camcorder video on a DVD blank so some Blu-ray players can play it. This is in development and waits for testing on real players.

## Retro consoles and old computers

The **Retro Console Optical Media** menu lists formats for the Wii, GameCube, PlayStation 1 and 2 and the original Xbox. Console discs are a preview: Krouton can lay out and inspect them, but most consoles need more than a correct image to play a burned disc, and Krouton doesn't promise that a given console will accept it. Only make copies of games you own.

The Data menu also has formats for old computers: Mac OS 9 discs with classic HFS and an Apple Partition Map, and strict 8.3 file names for DOS and Windows 95. Test such a disc on the machine it is for before burning a stack.
