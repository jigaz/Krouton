# Removed formats

Formats taken out of the catalogue (`OpticalWorkflowCatalog.swift`), with why, so nobody
re-adds them without knowing. Removed 2026-11-26 (commit 8a2afce), by decision of the owner.
The format count went from 31 to 28 (Suite 4 checks it).

## CD+G Karaoke (`cd-g`)

- **What it is:** Red Book audio with graphics (lyrics) in the R–W subchannels, 96 bytes per
  sector, read by karaoke machines.
- **Why removed:** writing it needs raw subchannel output (DAO with `DRSubchannelDataFormKey`
  and a producer for the packed R–W data), and few drives write R–W correctly. Krouton never
  had more than the audio editor for it; Burn refused it.
- **If it comes back:** the audio path (`KroutonAudioDiscRenderer`, `KroutonPCMTrackProducer`)
  would carry the audio; the producer would also need `producePreGap`/`produceData` to fill
  subchannel bytes from a .cdg file (24 packs of 24 bytes per sector).

## SACD-R / Scarlet Book DSD (`sacd-r`)

- **What it is:** Super Audio CD, 1-bit DSD audio.
- **Why removed:** no burner writes SACD. Real SACDs are pressed, with a physical
  watermark (PSP) that players check. "SACD-R" doesn't exist as a recordable format; DSD
  files can only go on a data disc or a DVD as DSD Disc, which few players read.
- **If it comes back:** as a data-disc preset ("DSD files for players that read DSD
  Disc"), not as SACD.

## PlayStation 3 BD-ROM (`console-ps3`)

- **What it was:** an entry that burned a PS3 .iso as it is.
- **Why removed:** a PS3 won't boot a burned BD-R of a game (the disc needs the ROM mark
  and keys only pressed discs carry), so the entry promised something no burn can deliver.
  A PS3 image can still be burned with **Burn Disc Image** as a plain data image.

## Merged earlier

- **VCD 2.0 / Super Video CD (`video-svcd`)** was a duplicate of White Book VCD / SVCD
  (`vcd-svcd`) and was merged into it (2026-11).
