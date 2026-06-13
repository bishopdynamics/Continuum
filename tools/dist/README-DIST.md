# Half-Life: Continuum Edition

A modified Xash3D FWGS engine that plays Half-Life 1 and its expansions with
**zero loading screens** — the whole campaign is preloaded behind the menu and
every level transition is a single frozen frame — plus a new gamepad-first
unified menu.

**What this is NOT:** a mod or a "remaster". There is no modified or
additional content and no gameplay changes. It is a new menu system (with a
few more of the engine's existing settings exposed) and a level streaming
system. You need to own the games: this package contains **no game content**.

## Setup

1. Copy the `valve` folder from your Half-Life installation
   (e.g. `Steam/steamapps/common/Half-Life/valve`) **into this folder**,
   merging it with the `valve` folder that is already here. Nothing gets
   overwritten — the files shipped here live on paths the game doesn't use.
2. Expansions work the same way: copy `gearbox` (Opposing Force), `bshift`
   (Blue Shift), or any other game/mod folder next to `valve`.
3. Run the game:
   - **Windows**: double-click `xash3d.exe`
   - **Linux**: run `./xash3d.sh`
   - Another game: add `-game gearbox` (etc.) to the command line.

The first launch scans your maps and preloads the campaign behind the menu
(a couple of seconds, roughly half a gigabyte of RAM for Half-Life). Turn
this off any time: Configuration > Advanced > Level Streaming.

## Notes

- The classic menu is available: Configuration > Interface > Classic Menu.
- Existing Xash3D FWGS / GoldSrc save games load fine.
- Multiplayer works but this build is tuned for singleplayer.
- The Windows build is tested under Wine; on Wine, controller hotplug is
  known to be unreliable (use the native Linux build there). Reports from
  real Windows hardware are welcome.
- The per-game menu artwork is generated from your own game files and is
  therefore not shipped. It is optional eye candy; if you want it, run
  `tools/compose_backgrounds.py <this folder> /tmp/bg --engine-assets`
  from the source tree (needs Python 3 + Pillow).
- Licenses: engine GPLv3 (source: see project page); controller glyphs by
  Xelu (CC0); Michroma & Fira Sans fonts under the SIL Open Font License
  (see `valve/gfx/fonts/`).
