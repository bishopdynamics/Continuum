#!/usr/bin/env python3
"""Ingest map-capture artifacts into redist/.

Companion to the in-game dev capture (sv_capture_maps 1, see hlsdk client.cpp):
playing through a game with capture on writes, per map first visited:

    dist-test/<game>/capture/<map>.png    clean screenshot (HUD + gun hidden)
    dist-test/<game>/capture/<map>.txt    weapons/items the player had on arrival

This script folds those into the repo:

  1. copies (downscaled) screenshots to
     redist/continuum/gfx/shell/continuum/chapters/<game>_<map>.png
  2. rewrites the loadout column of redist/continuum/gfx/shell/chapters_<game>.lst
     for each chapter, using the capture of *that chapter's currently-listed map*
     (so re-assigning a chapter to a different map and re-running picks up the new
     map's loadout). Chapters whose map has no capture are left untouched.

Re-runnable and idempotent. Use --dry-run to preview.

  tools/ingest-captures.py [--dry-run] [--game valve] [--no-scale]
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist-test"
REDIST = ROOT / "redist" / "continuum" / "gfx" / "shell"
THUMBS = REDIST / "continuum" / "chapters"

GAMES = ["valve", "gearbox", "bshift"]
THUMB_MAX_W = 512  # downscale wide screenshots to keep the repo lean

# a chapters.lst data line: "<map>" "<name>" "<loadout>"  (COM_ParseFile tokens)
LINE_RE = re.compile(r'^(\s*)"([^"]*)"(\s+)"([^"]*)"(\s+)"([^"]*)"(\s*)$')


def load_capture_loadout(txt: Path) -> str:
    """Read a capture .txt (one classname per line) into a space-joined loadout."""
    names = [ln.strip() for ln in txt.read_text().splitlines() if ln.strip()]
    return " ".join(names)


def copy_thumb(png: Path, dest: Path, scale: bool, dry: bool) -> str:
    if dry:
        return "would copy"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if scale:
        try:
            from PIL import Image
            im = Image.open(png)
            if im.width > THUMB_MAX_W:
                h = round(im.height * THUMB_MAX_W / im.width)
                im = im.resize((THUMB_MAX_W, h), Image.LANCZOS)
            im.save(dest)
            return "scaled"
        except ImportError:
            pass  # no PIL -> fall through to raw copy
    dest.write_bytes(png.read_bytes())
    return "copied"


def rewrite_chapters(lst: Path, loadouts: dict, dry: bool):
    """Swap each chapter's loadout token to loadouts[map]; preserve the line's
    original spacing (so unchanged chapters stay byte-identical) and leave
    comments, ordering and uncaptured maps intact. Returns (updated, skipped)."""
    if not lst.exists():
        return 0, 0

    out, updated, skipped = [], 0, 0
    for line in lst.read_text().splitlines():
        m = LINE_RE.match(line)
        if not m:
            out.append(line)
            continue
        lead, mapname, sp1, name, sp2, loadout, trail = m.groups()
        if mapname in loadouts:
            loadout = loadouts[mapname]
            updated += 1
        else:
            skipped += 1  # no capture for this map; keep existing loadout
        out.append(f'{lead}"{mapname}"{sp1}"{name}"{sp2}"{loadout}"{trail}')

    if not dry:
        lst.write_text("\n".join(out) + "\n")
    return updated, skipped


def ingest_game(game: str, scale: bool, dry: bool):
    cap = DIST / game / "capture"
    if not cap.is_dir():
        print(f"  {game}: no capture dir ({cap}) — skipped")
        return

    txts = sorted(cap.glob("*.txt"))
    pngs = sorted(cap.glob("*.png"))
    loadouts = {t.stem: load_capture_loadout(t) for t in txts}

    for png in pngs:
        dest = THUMBS / f"{game}_{png.stem}.png"
        how = copy_thumb(png, dest, scale, dry)
        print(f"  {game}: {png.name:<18} -> {dest.name}  [{how}]")

    lst = REDIST / f"chapters_{game}.lst"
    updated, skipped = rewrite_chapters(lst, loadouts, dry)
    print(f"  {game}: {len(loadouts)} captured map(s); "
          f"chapters updated={updated} untouched(no capture)={skipped}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="preview, write nothing")
    ap.add_argument("--game", choices=GAMES, help="only this game (default: all)")
    ap.add_argument("--no-scale", action="store_true", help="copy screenshots full-size")
    args = ap.parse_args()

    if not DIST.is_dir():
        sys.exit(f"no dist-test/ at {DIST} — run a capture playthrough first")

    games = [args.game] if args.game else GAMES
    print(f"{'DRY RUN: ' if args.dry_run else ''}ingesting captures -> redist/")
    for g in games:
        ingest_game(g, scale=not args.no_scale, dry=args.dry_run)
    print("done.")


if __name__ == "__main__":
    main()
