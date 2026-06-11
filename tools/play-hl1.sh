#!/bin/sh
# Play retail Half-Life 1 on the streaming engine.
#
# Launches into the menu; the campaign preloads behind it (~2 s), then start a
# New Game (or load a save) — every transition is a single frozen frame.
#
# Extra args are passed to the engine, e.g.:
#   tools/play-hl1.sh -windowed          # windowed mode
#   tools/play-hl1.sh -dev 2             # show [streamprof] transition timings
#   tools/play-hl1.sh +map c1a0          # jump straight to a map

cd "$(dirname "$0")/../install" || exit 1

if [ ! -x ./xash3d ]; then
    echo "engine not built — run tools/build-engine.sh first" >&2
    exit 1
fi

# make sure the campaign preload list exists (derived locally from your maps)
if [ ! -f valve/streampreload.cfg ]; then
    echo "generating valve/streampreload.cfg..."
    python3 ../tools/hlstream_preprocess.py valve/maps --campaign-only \
        -o ../cache/mapgraph-hl1.json --preload-cfg valve/streampreload.cfg || exit 1
fi

exec ./xash3d -log "$@"
