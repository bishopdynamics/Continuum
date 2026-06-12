#!/bin/sh
# Play They Hunger Trilogy on the streaming engine.
#
# Launches into the menu; the campaign preloads behind it, then start a New
# Game (or load a save) — every transition is a single frozen frame.
#
# Extra args are passed to the engine, e.g.:
#   tools/play-hunger.sh -windowed          # windowed mode
#   tools/play-hunger.sh -dev 2             # show [streamprof] transition timings

cd "$(dirname "$0")/../install" || exit 1

if [ ! -x ./xash3d ]; then
    echo "engine not built — run tools/build-engine.sh first" >&2
    exit 1
fi

# make sure the campaign preload list exists (derived locally from your maps)
if [ ! -f hunger/streampreload.cfg ]; then
    echo "generating hunger/streampreload.cfg..."
    python3 ../tools/hlstream_preprocess.py ../cache/mapgraph-hunger.json \
        --preload-cfg hunger/streampreload.cfg || exit 1
fi

exec ./xash3d -console -log -game hunger "$@"
