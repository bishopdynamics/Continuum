#!/bin/bash
# Native (non-Docker) engine rebuild for the local dev loop: build the engine
# in place and install it into ./install so play-continuum.sh / `make play`
# can run it.
#
# Self-configures waf when it isn't validly configured for this tree — which
# is the case on a fresh clone (never configured) and after a move/rename
# (the waf lock points at the old path). The reproducible from-scratch
# packaging path is tools/dist/ (Docker); this is just the fast local loop.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG=/tmp/xash-build.log
cd "$ROOT/xash3d-fwgs"

build() { ./waf build -j"$(nproc)"; }

if ! build > "$LOG" 2>&1; then
    if grep -qiE "not configured|invalid lock file" "$LOG"; then
        echo "=== waf not configured for this tree — configuring ==="
        ./waf configure -T release -8 --sdl2="$ROOT/.deps/sdl2" >> "$LOG" 2>&1
        build >> "$LOG" 2>&1 || { grep -iE "error" "$LOG" | tail -20; exit 1; }
    else
        grep -iE "error" "$LOG" | tail -20; exit 1
    fi
fi
./waf install --destdir="$ROOT/install" >> "$LOG" 2>&1
echo BUILD-AND-INSTALL-OK
