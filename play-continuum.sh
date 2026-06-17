#!/bin/sh
# Play any installed game, expansion or mod on the streaming engine.
#
# Usage: ./play-continuum.sh [game] [engine args...]
#
#   game    a game directory under dist-test/ (default: valve), or an alias:
#             hl, hl1        -> valve    (Half-Life)
#             of, opfor      -> gearbox  (Opposing Force)
#             bs, blueshift  -> bshift   (Blue Shift)
#           any other installed mod dir works too: ./play-continuum.sh mymod
#
# Launches into the menu; the engine scans the game's own maps (loose files
# and pak archives alike), derives the campaign graph and preloads it behind
# the menu — every transition is a single frozen frame. You can also switch
# games from inside the menu (Game page).
#
# Extra args are passed to the engine, e.g.:
#   ./play-continuum.sh -windowed            # windowed mode
#   ./play-continuum.sh of -dev 2            # Opposing Force with [streamprof] timings
#   ./play-continuum.sh valve +map c1a0      # jump straight to a map

GAME=valve
case "$1" in
    ""|-*|+*) ;; # no game named, all args go to the engine
    hl|hl1) GAME=valve; shift ;;
    of|opfor) GAME=gearbox; shift ;;
    bs|blueshift) GAME=bshift; shift ;;
    *) GAME=$1; shift ;;
esac

ROOT="$(dirname "$0")"

# refresh the editable overlay assets from redist/ into dist-test/ on every run,
# so the quick-test path picks up edits to chapter lists, menu art, etc. without
# a full dogfood rebuild. Mirrors stage_assets in tools/build_all.sh
# (redist/<dir>/ -> dist-test/<dir>/); engine + game libs still come from a build.
if [ -d "$ROOT/redist" ] && [ -d "$ROOT/dist-test" ]; then
    echo ">> syncing redist/ -> dist-test/ ..."
    cp -av "$ROOT"/redist/. "$ROOT/dist-test/" | sed 's/^/   /'
    echo ">> redist sync done"
fi

cd "$ROOT/dist-test" || { echo "no dist-test/ — run tools/dogfood.sh first" >&2; exit 1; }

if [ ! -x ./xash3d ]; then
    echo "engine not built — run tools/dogfood.sh (or tools/build-engine.sh) first" >&2
    exit 1
fi

if [ ! -f "$GAME/liblist.gam" ] && [ ! -f "$GAME/gameinfo.txt" ]; then
    echo "no game installed at dist-test/$GAME — installed games:" >&2
    for d in */; do
        d=${d%/}
        [ -f "$d/liblist.gam" ] || [ -f "$d/gameinfo.txt" ] && echo "  $d" >&2
    done
    exit 1
fi

# no -console: the in-game toggle governs it (Configuration > Advanced >
# Console); pass -console or -dev yourself for development sessions
echo ">> starting game: $GAME ($*)"
exec ./xash3d -log -game "$GAME" "$@"
