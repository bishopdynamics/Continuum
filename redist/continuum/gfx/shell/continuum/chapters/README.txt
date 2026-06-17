Chapter thumbnails
==================

Drop a thumbnail here for each chapter's starting map, named:

    <gamefolder>_<map>.png

e.g.  valve_c2a2.png      (Half-Life, On A Rail)
      gearbox_of4a1.png   (Opposing Force, Vicarious Reality)
      bshift_ba_canal1.png(Blue Shift, Duty Calls)

The Chapters menu loads gfx/shell/continuum/chapters/<gamefolder>_<map>.png
for each entry in gfx/shell/chapters_<gamefolder>.lst, and falls back to
placeholder.png when the file is missing.

Thumbnails are 4:3 and drawn aspect-fit, so exact size is not critical;
~320x240 (matching placeholder.png) up to the capture resolution is fine.

A future engine feature ("screenshot-each-map", see Notes.md) will auto-capture
these right after each map load; for now they are placed here by hand.
