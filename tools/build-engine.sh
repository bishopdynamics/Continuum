#!/bin/bash
# Native (non-Docker) engine rebuild for the local dev loop: build the engine
# in place and install it over ./dist-test so play-continuum.sh / `make play`
# can run it. (dist-test is populated by a full dogfood build — tools/dogfood.sh
# — which lays down the game libs + content; this just refreshes the engine fast.)
#
# Self-configures waf when it isn't validly configured for this tree — which
# is the case on a fresh clone (never configured) and after a move/rename
# (the waf lock points at the old path). The reproducible from-scratch
# packaging path is tools/dist/ (Docker); this is just the fast local loop.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG=/tmp/xash-build.log
cd "$ROOT/xash3d-fwgs"

# Portable CPU count (Linux: nproc; macOS has no nproc).
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu)

# Per-OS configure flags. Linux: 64-bit (-8) against the locally built SDL2 in
# .deps/. macOS: native arch (no -8 — arm64 DEST_CPU is auto) and SDL2 from the
# Apple framework. The engine's sdl2.py only auto-finds the framework in
# /Library/Frameworks, so we point --sdl2 at whichever SDL2.framework is present
# (prefer the per-user path, which needs no sudo to install).
SDL2_FW=""
if [ "$(uname -s)" = "Darwin" ]; then
    for fw in "$HOME/Library/Frameworks/SDL2.framework" /Library/Frameworks/SDL2.framework; do
        [ -d "$fw" ] && { SDL2_FW=$fw; break; }
    done
    [ -n "$SDL2_FW" ] || { echo "SDL2.framework not found in ~/Library/Frameworks or /Library/Frameworks" >&2; exit 1; }
    CONFIGURE_FLAGS=(-T release --sdl2="$SDL2_FW")
else
    CONFIGURE_FLAGS=(-T release -8 --sdl2="$ROOT/.deps/sdl2")
fi

build() { ./waf build -j"$NPROC"; }

if ! build > "$LOG" 2>&1; then
    if grep -qiE "not configured|invalid lock file" "$LOG"; then
        echo "=== waf not configured for this tree — configuring ==="
        ./waf configure "${CONFIGURE_FLAGS[@]}" >> "$LOG" 2>&1
        build >> "$LOG" 2>&1 || { grep -iE "error" "$LOG" | tail -20; exit 1; }
    else
        grep -iE "error" "$LOG" | tail -20; exit 1
    fi
fi
./waf install --destdir="$ROOT/dist-test" >> "$LOG" 2>&1

# macOS: libxash references SDL2 as @rpath/SDL2.framework and the launcher's
# rpath is @loader_path (the install dir), so the framework must sit next to the
# binary — mirrors how the dist bundle ships it. Symlink it in for the dev loop.
if [ -n "$SDL2_FW" ] && [ ! -e "$ROOT/dist-test/SDL2.framework" ]; then
    ln -s "$SDL2_FW" "$ROOT/dist-test/SDL2.framework"
fi
echo BUILD-AND-INSTALL-OK
