#!/bin/sh
# Runs INSIDE the linux build container. The source tree is mounted
# read-only at /src; build from a copy so the host's own build dirs and
# waf lockfiles are never touched. Installs everything into /out.
set -e

ARCH=$(uname -m)
EXTRA=""
[ "$ARCH" = "x86_64" ] && EXTRA="-8"

export HOME=/tmp

mkdir -p /tmp/b/engine /tmp/b/hlsdk
( cd /src/xash3d-fwgs && tar cf - --exclude=./build . ) | tar xf - -C /tmp/b/engine
( cd /src/hlsdk-portable && tar cf - --exclude=./build . ) | tar xf - -C /tmp/b/hlsdk

echo "=== engine ($ARCH) ==="
cd /tmp/b/engine
./waf configure -T release $EXTRA --enable-lto --enable-bundled-deps \
    --enable-stbtt --enable-all-renderers --sdl2=/opt/SDL2
./waf build
./waf install --destdir=/out

echo "=== game libraries ($ARCH) ==="
cd /tmp/b/hlsdk
./waf configure -T release $EXTRA
./waf build
./waf install --destdir=/out

echo "=== bundle SDL2 ==="
cp -av /opt/SDL2/lib/libSDL2-2.0.so* /out/

echo "container build done:"
ls -la /out
