#!/usr/bin/env python3
"""Extract the controller glyphs the Continuum menu uses from Kenney's
Input Prompts pack (CC0, https://kenney.nl/assets/input-prompts) into
valve/gfx/shell/continuum/glyphs/<style>/<logical>.png.

Usage: extract_glyphs.py <kenney_zip> <install_dir>
"""

import os
import sys
import zipfile

# logical glyph -> source file inside the pack, per style ("Double" = 2x PNGs)
STYLES = {
    "xbox": {
        "a": "Xbox Series/Double/xbox_button_color_a.png",
        "b": "Xbox Series/Double/xbox_button_color_b.png",
        "x": "Xbox Series/Double/xbox_button_color_x.png",
        "y": "Xbox Series/Double/xbox_button_color_y.png",
        "lb": "Xbox Series/Double/xbox_lb.png",
        "rb": "Xbox Series/Double/xbox_rb.png",
        "start": "Xbox Series/Double/xbox_button_menu.png",
        "back": "Xbox Series/Double/xbox_button_view.png",
    },
    "ps": {
        "a": "PlayStation Series/Double/playstation_button_color_cross.png",
        "b": "PlayStation Series/Double/playstation_button_color_circle.png",
        "x": "PlayStation Series/Double/playstation_button_color_square.png",
        "y": "PlayStation Series/Double/playstation_button_color_triangle.png",
        "lb": "PlayStation Series/Double/playstation_trigger_l1.png",
        "rb": "PlayStation Series/Double/playstation_trigger_r1.png",
        "start": "PlayStation Series/Double/playstation5_button_options.png",
        "back": "PlayStation Series/Double/playstation5_button_create.png",
    },
    "switch": {
        "a": "Nintendo Switch/Double/switch_button_a.png",
        "b": "Nintendo Switch/Double/switch_button_b.png",
        "x": "Nintendo Switch/Double/switch_button_x.png",
        "y": "Nintendo Switch/Double/switch_button_y.png",
        "lb": "Nintendo Switch/Double/switch_button_l.png",
        "rb": "Nintendo Switch/Double/switch_button_r.png",
        "start": "Nintendo Switch/Double/switch_button_plus.png",
        "back": "Nintendo Switch/Double/switch_button_minus.png",
    },
    "deck": {
        "a": "Steam Deck/Double/steamdeck_button_a.png",
        "b": "Steam Deck/Double/steamdeck_button_b.png",
        "x": "Steam Deck/Double/steamdeck_button_x.png",
        "y": "Steam Deck/Double/steamdeck_button_y.png",
        "lb": "Steam Deck/Double/steamdeck_button_l1.png",
        "rb": "Steam Deck/Double/steamdeck_button_r1.png",
        "start": "Steam Deck/Double/steamdeck_button_options.png",
        "back": "Steam Deck/Double/steamdeck_button_view.png",
    },
    "kb": {
        "a": "Keyboard & Mouse/Double/keyboard_enter.png",
        "b": "Keyboard & Mouse/Double/keyboard_escape.png",
        "x": "Keyboard & Mouse/Double/keyboard_x.png",
        "y": "Keyboard & Mouse/Double/keyboard_y.png",
        "lb": "Keyboard & Mouse/Double/keyboard_page_up.png",
        "rb": "Keyboard & Mouse/Double/keyboard_page_down.png",
        "start": "Keyboard & Mouse/Double/keyboard_tab.png",
        "back": "Keyboard & Mouse/Double/keyboard_backspace.png",
    },
}


def main():
    zip_path, install = sys.argv[1], sys.argv[2]
    outroot = os.path.join(install, "valve", "gfx", "shell", "continuum", "glyphs")
    missing = 0
    with zipfile.ZipFile(zip_path) as z:
        names = set(z.namelist())
        for style, glyphs in STYLES.items():
            outdir = os.path.join(outroot, style)
            os.makedirs(outdir, exist_ok=True)
            for logical, src in glyphs.items():
                if src not in names:
                    print(f"MISSING {style}/{logical}: {src}", file=sys.stderr)
                    missing += 1
                    continue
                with open(os.path.join(outdir, f"{logical}.png"), "wb") as f:
                    f.write(z.read(src))
        lic = "License.txt"
        if lic in names:
            with open(os.path.join(outroot, "LICENSE-kenney.txt"), "wb") as f:
                f.write(z.read(lic))
    print(f"done, {missing} missing")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
