#!/bin/sh
# Play any installed game, expansion or mod on the streaming engine.
#
# Usage: ./play-continuum.sh [game] [engine args...]
#
#   game    a game directory under install/ (default: valve), or an alias:
#             hl, hl1        -> valve    (Half-Life)
#             of, opfor      -> gearbox  (Opposing Force)
#             bs, blueshift  -> bshift   (Blue Shift)
#           any other installed mod dir works too: ./play-continuum.sh mymod
#
# Launches into the menu; the campaign preloads behind it (~2 s), then start a
# New Game (or load a save) — every transition is a single frozen frame.
# You can also switch games from inside the menu (Game page).
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

cd "$(dirname "$0")/install" || exit 1

if [ ! -x ./xash3d ]; then
    echo "engine not built — run tools/build-engine.sh first" >&2
    exit 1
fi

if [ ! -f "$GAME/liblist.gam" ] && [ ! -f "$GAME/gameinfo.txt" ]; then
    echo "no game installed at install/$GAME — installed games:" >&2
    for d in */; do
        d=${d%/}
        [ -f "$d/liblist.gam" ] || [ -f "$d/gameinfo.txt" ] && echo "  $d" >&2
    done
    exit 1
fi

# make sure the campaign preload list exists (derived locally from your own
# maps — never distributed). Streaming works without it; the preload just
# warms every map up front so even first visits are instant.
if [ ! -f "$GAME/streampreload.cfg" ]; then
    graph="../cache/mapgraph-$GAME.json"
    # earlier per-game launchers used short graph names; reuse those caches
    case "$GAME" in
        valve)   [ -f "$graph" ] || [ ! -f ../cache/mapgraph-hl1.json ] || graph=../cache/mapgraph-hl1.json ;;
        gearbox) [ -f "$graph" ] || [ ! -f ../cache/mapgraph-of.json ]  || graph=../cache/mapgraph-of.json ;;
        bshift)  [ -f "$graph" ] || [ ! -f ../cache/mapgraph-bs.json ]  || graph=../cache/mapgraph-bs.json ;;
    esac

    if [ -f "$graph" ]; then
        echo "generating $GAME/streampreload.cfg from $graph..."
        python3 ../tools/hlstream_preprocess.py "$graph" \
            --preload-cfg "$GAME/streampreload.cfg" || exit 1
    elif ls "$GAME"/maps/*.bsp >/dev/null 2>&1; then
        echo "generating $GAME/streampreload.cfg from $GAME/maps..."
        python3 ../tools/hlstream_preprocess.py "$GAME/maps" \
            -o "../cache/mapgraph-$GAME.json" \
            --preload-cfg "$GAME/streampreload.cfg" || exit 1
    else
        echo "note: no loose .bsp maps under install/$GAME/maps (pak archives?)"
        echo "      skipping the preload list — transitions still stream, but each"
        echo "      map pays a small one-time cost on first visit"
    fi
fi

exec ./xash3d -console -log -game "$GAME" "$@"
