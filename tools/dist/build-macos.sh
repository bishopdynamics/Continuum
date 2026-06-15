#!/bin/bash
# Build the macOS universal (arm64 + x86_64) Continuum bundle.
#
# Unlike the linux/win32 targets this is NOT a Docker build: macOS binaries
# need Apple's SDK, which only exists on macOS. So this must run natively on
# a Mac. On any other host it just prints guidance and exits non-zero.
#
# Status: STUB. The native build steps land during the macOS pass (see the
# v1 roadmap in Notes.md). Reference for the engine's own Apple build:
#   xash3d-fwgs/scripts/gha/build_apple.sh
set -e

if [ "$(uname -s)" != "Darwin" ]; then
    cat <<'EOF'
macos: cannot be built from this host — Apple's SDK only runs on macOS.

On a Mac:
  1. install SDL2 (brew install sdl2, or drop SDL2.framework in
     /Library/Frameworks)
  2. git clone --recursive this repo
  3. make macos
EOF
    exit 1
fi

echo "macos: native build not implemented yet (TODO during the macOS pass)."
echo "Reference: xash3d-fwgs/scripts/gha/build_apple.sh"
exit 1
