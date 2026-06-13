#!/bin/sh
# Half-Life: Continuum Edition launcher — prefers the bundled SDL2.
cd "$(dirname "$0")" || exit 1
LD_LIBRARY_PATH="$PWD${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" exec ./xash3d -log "$@"
