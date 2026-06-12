#!/usr/bin/env python3
"""Composite each game's menu background into a single image.

Steam-era games ship the 800x600 menu background as 12 TGA tiles laid out by
resource/BackgroundLayout.txt; WON-era games (uplink, dayone) ship a single
gfx/shell/splash.bmp inside pak0.pak. This tool normalizes all of them to one
PNG per game, used by the menu mockups and later extracted as real menu assets.

Usage: compose_backgrounds.py <install_dir> <out_dir> [--engine-assets]

With --engine-assets, also writes the Continuum menu assets into
<install_dir>/valve/gfx/shell/continuum/games/: <game>.png (sharp art for the
cards / game page) and <game>_bd.png (pre-blurred darkened full-screen
backdrop — the renderer has no blur, so it's baked here).
"""

import io
import os
import struct
import sys

from PIL import Image, ImageEnhance, ImageFilter

GAMES = ["valve", "gearbox", "bshift", "uplink", "hunger", "dayone"]

TILE_GRID = [(c, r) for r in range(3) for c in range(4)]  # 4 cols x 3 rows


def pak_entries(pak_path):
    with open(pak_path, "rb") as f:
        magic, diroff, dirlen = struct.unpack("<4sii", f.read(12))
        if magic != b"PACK":
            raise ValueError(f"{pak_path}: not a pak file")
        f.seek(diroff)
        for _ in range(dirlen // 64):
            name, off, size = struct.unpack("<56sii", f.read(64))
            yield name.split(b"\0", 1)[0].decode("latin-1"), off, size


def pak_read(pak_path, want_name):
    want = want_name.lower()
    with open(pak_path, "rb") as f:
        for name, off, size in pak_entries(pak_path):
            if name.lower() == want:
                f.seek(off)
                return f.read(size)
    return None


def find_paks(gamedir):
    return sorted(
        os.path.join(gamedir, n)
        for n in os.listdir(gamedir)
        if n.lower().endswith(".pak")
    )


def load_vfs(gamedir, relpath):
    """Read a file from the gamedir, falling back to its pak files."""
    disk = os.path.join(gamedir, relpath)
    if os.path.exists(disk):
        with open(disk, "rb") as f:
            return f.read()
    for pak in find_paks(gamedir):
        data = pak_read(pak, relpath)
        if data is not None:
            return data
    return None


def compose_tiles(gamedir):
    tiles = []
    for col, row in TILE_GRID:
        rel = f"resource/background/800_{row + 1}_{'abcd'[col]}_loading.tga"
        data = load_vfs(gamedir, rel)
        if data is None:
            return None
        tiles.append((col * 256, row * 256, Image.open(io.BytesIO(data))))
    canvas = Image.new("RGB", (800, 600))
    for x, y, img in tiles:
        canvas.paste(img, (x, y))
    return canvas


def load_splash(gamedir):
    data = load_vfs(gamedir, "gfx/shell/splash.bmp")
    if data is None:
        return None
    return Image.open(io.BytesIO(data)).convert("RGB")


def make_backdrop(img):
    """Blurred, darkened 16:9 cover-fill — what CSS blur+brightness did in
    the mockups."""
    bd = img.resize((480, 270))
    bd = bd.filter(ImageFilter.GaussianBlur(10))
    return ImageEnhance.Brightness(bd).enhance(0.35)


def main():
    install, outdir = sys.argv[1], sys.argv[2]
    engine_assets = "--engine-assets" in sys.argv
    os.makedirs(outdir, exist_ok=True)
    games_dir = os.path.join(install, "valve", "gfx", "shell", "continuum", "games")
    if engine_assets:
        os.makedirs(games_dir, exist_ok=True)
    for game in GAMES:
        gamedir = os.path.join(install, game)
        img = compose_tiles(gamedir) or load_splash(gamedir)
        if img is None:
            print(f"{game}: NO background found", file=sys.stderr)
            continue
        out = os.path.join(outdir, f"{game}.png")
        img.save(out)
        print(f"{game}: {img.size[0]}x{img.size[1]} -> {out}")
        if engine_assets:
            img.save(os.path.join(games_dir, f"{game}.png"))
            make_backdrop(img).save(os.path.join(games_dir, f"{game}_bd.png"))


if __name__ == "__main__":
    main()
