# Disc labels

The Polar Disc Label Studio (⌘4) designs printable disc faces at true size: 120 mm for standard discs, 80 mm for mini discs, with the centre hole shown so nothing important lands on it.

## Starting from your music or files

Click **Auto Label**. Krouton looks for artwork among the files you staged: a picture file, cover art embedded in a music or video file, or a cover.jpg, folder.jpg or front.jpg next to them. It picks a colour palette from the picture and uses Apple's Vision framework to find the subject, so a face or logo is kept clear of the centre hole. The title and artist come from the disc's details.

Everything Auto Label places can be changed afterwards.

## Text that follows the disc

- **Edit › Add Curved Text Layer** (⌘T) adds text that runs along an arc of the disc.
- **Edit › Duplicate Selected Text Layer** (⌘D) copies it to the opposite side, turned so it reads upright at the bottom too.
- **Edit › Delete Selected Text Layer** (⌘⌫) removes it.

Set the radius, start angle, size and font in the text inspector. Shapes you draw freehand are tidied into clean vector lines and circles.

## Lining things up

**View › Show 10mm Alignment Grid** (⌘G) overlays a millimetre grid. Zoom with ⌘+ and ⌘−; ⌥⌘0 returns to actual size.

## Printing

- **Export 1:1 PDF** makes a vector sheet at exact millimetre scale, for a printer with a disc tray or for sticker label sheets.
- **Export 300-DPI PNG** makes a picture for printers or services that want an image.

Printers that print directly on discs rarely place the disc exactly where the driver expects. Print one test on paper, measure how far off the circle is, and save the X and Y offsets as a preset in Settings › Labels & Printers. A preset for the Epson EcoTank ET-8550 and standard trays is included; add one for each printer you use.

Print on printable discs only: they have a matte white or silver face made to take ink. Let the ink dry before putting the disc in a drive.
