#!/bin/sh
# Runs INSIDE the linux build container. The source tree is mounted
# read-only at /src; build from a copy so the host's own build dirs and
# waf lockfiles are never touched. Installs everything into /out.
set -e

ARCH=$(uname -m)
EXTRA=""
[ "$ARCH" = "x86_64" ] && EXTRA="-8"   # 64-bit; arm64 needs no flag (DEST_CPU auto)

export HOME=/tmp

mkdir -p /tmp/b/engine
( cd /src/xash3d-fwgs && tar cf - --exclude=./build . ) | tar xf - -C /tmp/b/engine

echo "=== engine ($ARCH) ==="
cd /tmp/b/engine
./waf configure -T release $EXTRA --enable-lto --enable-bundled-deps \
    --enable-stbtt --enable-all-renderers --sdl2=/opt/SDL2
./waf build
./waf install --destdir=/out

echo "=== game libraries ($ARCH) ==="
# Build every supported mod's game libs from its own hlsdk-portable branch
# (master=valve, opfor=gearbox, bshift, theyhunger=hunger, ...). The branch loop
# + manifest live in build-game-libs.sh; CONFIGURE_FLAGS selects the target —
# here, this container's arch. The same script serves win32/macOS later with a
# different toolchain + flags.
CONFIGURE_FLAGS="-T release $EXTRA" OUT=/out \
    python3 /src/tools/dist/build-game-libs.py

echo "=== bundle SDL2 ==="
cp -av /opt/SDL2/lib/libSDL2-2.0.so* /out/

echo "container build done:"
ls -la /out
