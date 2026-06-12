#!/usr/bin/env python3
"""Generate the Continuum menu's small procedural UI assets into
valve/gfx/shell/continuum/: lambda.png (brand mark), pill.png (toggle track,
white capsule for tinting), dot.png (toggle knob), chip_current.png (the
rounded CURRENT tag on game cards, text baked in).

Usage: make_ui_assets.py <install_dir> [michroma_ttf]
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont


def lambda_mark(outdir):
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 200)
    img = Image.new("RGBA", (220, 240), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((110, 110), "λ", font=f, fill=(255, 163, 26, 255), anchor="mm")
    img.crop(img.getbbox()).save(os.path.join(outdir, "lambda.png"))


def pill(outdir):
    # white capsule at 4x for clean downscaled edges; drawn at w=2h in menu
    img = Image.new("RGBA", (320, 160), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 319, 159), radius=80, fill=(255, 255, 255, 255))
    img.resize((80, 40), Image.LANCZOS).save(os.path.join(outdir, "pill.png"))


def dot(outdir):
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((8, 8, 247, 247), fill=(255, 255, 255, 255))
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(outdir, "dot.png"))


def chip_current(outdir, ttf):
    f = ImageFont.truetype(ttf, 44)
    text = "CURRENT"
    tw = int(f.getlength(text))
    w, h = tw + 64, 88
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2, fill=(255, 163, 26, 255))
    d.text((w // 2, h // 2 - 2), text, font=f, fill=(20, 17, 10, 255), anchor="mm")
    img.resize((w // 2, h // 2), Image.LANCZOS).save(os.path.join(outdir, "chip_current.png"))


def main():
    install = sys.argv[1]
    ttf = sys.argv[2] if len(sys.argv) > 2 else "docs/mockups/assets/fonts/Michroma.ttf"
    outdir = os.path.join(install, "valve", "gfx", "shell", "continuum")
    os.makedirs(outdir, exist_ok=True)
    lambda_mark(outdir)
    pill(outdir)
    dot(outdir)
    chip_current(outdir, ttf)
    print("ok:", ", ".join(["lambda.png", "pill.png", "dot.png", "chip_current.png"]))


if __name__ == "__main__":
    main()
