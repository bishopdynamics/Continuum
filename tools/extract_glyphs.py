#!/usr/bin/env python3
"""Copy the controller glyphs the Continuum menu uses from Xelu's Free
Controller & Key Prompts pack (CC0, https://thoseawesomeguys.com/prompts/)
into valve/gfx/shell/continuum/glyphs/<style>/<logical>.png.

Usage: extract_glyphs.py <xelu_dir> <install_dir>
"""

import os
import shutil
import sys

# logical glyph -> source file inside the pack, per style
STYLES = {
    "xbox": {
        "a": "Xbox Series/XboxSeriesX_A.png",
        "b": "Xbox Series/XboxSeriesX_B.png",
        "x": "Xbox Series/XboxSeriesX_X.png",
        "y": "Xbox Series/XboxSeriesX_Y.png",
        "lb": "Xbox Series/XboxSeriesX_LB.png",
        "rb": "Xbox Series/XboxSeriesX_RB.png",
        "start": "Xbox Series/XboxSeriesX_Menu.png",
        "back": "Xbox Series/XboxSeriesX_View.png",
    },
    "ps": {
        "a": "PS5/PS5_Cross.png",
        "b": "PS5/PS5_Circle.png",
        "x": "PS5/PS5_Square.png",
        "y": "PS5/PS5_Triangle.png",
        "lb": "PS5/PS5_L1.png",
        "rb": "PS5/PS5_R1.png",
        "start": "PS5/PS5_Options.png",
        "back": "PS5/PS5_Share.png",
    },
    "switch": {
        "a": "Switch/Switch_A.png",
        "b": "Switch/Switch_B.png",
        "x": "Switch/Switch_X.png",
        "y": "Switch/Switch_Y.png",
        "lb": "Switch/Switch_LB.png",
        "rb": "Switch/Switch_RB.png",
        "start": "Switch/Switch_Plus.png",
        "back": "Switch/Switch_Minus.png",
    },
    "deck": {
        "a": "Steam Deck/SteamDeck_A.png",
        "b": "Steam Deck/SteamDeck_B.png",
        "x": "Steam Deck/SteamDeck_X.png",
        "y": "Steam Deck/SteamDeck_Y.png",
        "lb": "Steam Deck/SteamDeck_L1.png",
        "rb": "Steam Deck/SteamDeck_R1.png",
        "start": "Steam Deck/SteamDeck_Menu.png",
        "back": "Steam Deck/SteamDeck_Square.png",
    },
    "kb": {
        "a": "Keyboard & Mouse/Dark/Enter_Key_Dark.png",
        "b": "Keyboard & Mouse/Dark/Esc_Key_Dark.png",
        "x": "Keyboard & Mouse/Dark/X_Key_Dark.png",
        "y": "Keyboard & Mouse/Dark/Y_Key_Dark.png",
        "lb": "Keyboard & Mouse/Dark/Page_Up_Key_Dark.png",
        "rb": "Keyboard & Mouse/Dark/Page_Down_Key_Dark.png",
        "start": "Keyboard & Mouse/Dark/Tab_Key_Dark.png",
        "back": "Keyboard & Mouse/Dark/Backspace_Key_Dark.png",
    },
}

LICENSE_NOTE = """Controller & key prompt images from Xelu's Free Controller
& Key Prompts pack: https://thoseawesomeguys.com/prompts/

Public domain under Creative Commons 0 (CC0), per the pack's Readme.
"""


def main():
    pack, install = sys.argv[1], sys.argv[2]
    outroot = os.path.join(install, "valve", "gfx", "shell", "continuum", "glyphs")
    missing = 0
    for style, glyphs in STYLES.items():
        outdir = os.path.join(outroot, style)
        os.makedirs(outdir, exist_ok=True)
        for logical, src in glyphs.items():
            path = os.path.join(pack, src)
            if not os.path.exists(path):
                print(f"MISSING {style}/{logical}: {src}", file=sys.stderr)
                missing += 1
                continue
            shutil.copyfile(path, os.path.join(outdir, f"{logical}.png"))
    with open(os.path.join(outroot, "LICENSE-glyphs.txt"), "w") as f:
        f.write(LICENSE_NOTE)
    print(f"done, {missing} missing")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
