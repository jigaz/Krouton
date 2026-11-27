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

## Panorama planets

**Background › Panorama Planet** wraps a panorama photo into the disc with polar coordinates: the bottom of the photo meets in the middle, the horizon becomes a circle, and the sky runs round the rim, like the little-planet photos a 360° camera makes. Click **Choose a Panorama…** in the Planet tool. A 360° panorama twice as wide as it is tall wraps without a seam; for a narrower photo, choose **Blend the ends** or **Mirror** under Seam.

- **Little Planet** curves the ground into a small globe and opens the sky out; **Polar Coordinates** spaces the photo evenly from the middle to the rim, like Photoshop's filter. **Tunnel** turns it inside out, with the sky in the middle.
- **Planet Size** sets how far out the horizon lands; **Rotation** turns the planet and **Twist** swirls it. In Polar Coordinates, **Ground Curve** squeezes the ground towards the middle or spreads it out.
- **Horizon in Photo** says where the photo's horizon is (or drag on the photo); **Crop Sky** and **Crop Ground** leave out the top or bottom.
- **Start at the hub's edge** begins the photo at the edge of the hole, so its stretched middle isn't printed. **Fade at the Rim** and **Fade at the Centre** blend into a colour you choose, which keeps text readable there.
- **Smoothing** samples each pixel several times; **Starting Points** gives four ready-made settings. Adjust's colour, contrast and blur apply to the planet too.

Krouton keeps a link to the photo, not a copy: if you move it, choose it again.

## Lining things up

**View › Show 10mm Alignment Grid** (⌘G) overlays a millimetre grid. Zoom with ⌘+ and ⌘−; ⌥⌘0 returns to actual size.

## Printing

The Print tool holds the print settings, and the exports use them:

- **Print On**: a printable disc in an inkjet tray, or US Letter paper. For a disc, **Export PNG** and open the picture in your printer's disc software (Epson Print CD, Canon IJ Label Print) at 100 %. **Export PDF** places the same artwork at 1:1 on a sheet, with the tray offsets.
- **Resolution**: 300 or 600 dpi for Canon and HP, 360 or 720 for Epson.
- **Bleed** carries the artwork 1 mm or so past the rim and into the hub, so a print slightly off centre leaves no white edge. Keep text a few millimetres inside the rim.
- **Ink Density** and **Lift Shadows** lighten the artwork for glossy or water-resistant discs, which take less ink than matte ones. They're applied when you export; **Show the density on the canvas** previews the density.

Printers that print directly on discs rarely place the disc exactly where the driver expects. Click **Alignment Test** (or **Save Alignment Test** in the Print tool) and print the sheet on a spare disc: its rings are 1 mm apart, so you can read how far the crosshair is from the disc's centre. Enter that as **Offset X** and **Offset Y** (positive X moves the print right, positive Y down), and save it as a preset in the Disc Size tool. A preset for the Epson EcoTank ET-8550 and standard trays is included; add one for each printer you use.

Print on printable discs only: they have a matte white or silver face made to take ink. Let the ink dry before putting the disc in a drive.
