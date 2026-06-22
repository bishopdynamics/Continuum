#!/bin/bash
# Half-Life: Continuum Edition — in-bundle launcher.
# Installed as Continuum.app/Contents/MacOS/Continuum (the CFBundleExecutable).
#
# Mirrors the flatpak's launcher (tools/dist/flatpak/continuum.sh): the .app
# ships the engine, the game libraries and the Continuum menu assets — never
# game content. Those live read-only inside the bundle and are mounted as the
# engine's RODIR. Everything the engine writes (configs, saves) and the player's
# own game files live in a writable BASEDIR under ~/Library/Application Support.
#
# A Finder-launched .app starts with cwd "/", so we set the engine's data roots
# explicitly via the env vars it reads (XASH3D_RODIR / XASH3D_BASEDIR) rather
# than relying on the working directory.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"        # Contents/MacOS
RES="$(cd "$HERE/../Resources" && pwd)"      # Contents/Resources (read-only overlay)

# read-only overlay: per-game .dylib libs (valve/gearbox/bshift/hunger) + the
# always-mounted continuum/ assets (menu, fonts, glyphs).
export XASH3D_RODIR="$RES"

# writable base: the player drops their own game folders here; saves/configs
# land here too. Checked before the engine's built-in .app pref-path logic, so
# this name (not the engine's) is what shows up under Application Support.
BASE="$HOME/Library/Application Support/Continuum"
mkdir -p "$BASE/valve"
export XASH3D_BASEDIR="$BASE"

# first run / no content yet: reveal the data folder in Finder and tell the
# player what to add, instead of dropping into the engine's hard "couldn't find
# game data" error (which a Finder launch would never show).
if [ ! -e "$BASE/valve/liblist.gam" ] && [ ! -e "$BASE/valve/gameinfo.txt" ]; then
    open "$BASE" 2>/dev/null || true
    osascript -e 'display dialog "Add your Half-Life game data to continue.

Copy your “valve” folder (e.g. from Steam/steamapps/common/Half-Life) into the folder that just opened, then launch Continuum again.

Expansions work the same way: also copy gearbox (Opposing Force), bshift (Blue Shift) or hunger (They Hunger)." with title "Half-Life: Continuum Edition" buttons {"OK"} default button "OK"' >/dev/null 2>&1 || true
    exit 0
fi

exec "$HERE/xash3d" -log -game valve "$@"
