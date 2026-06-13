#!/bin/sh
# Runs INSIDE the win32 (mingw i686) build container. Source mounted
# read-only at /src; builds from a copy, installs into /out.
set -e

export HOME=/tmp
export CC=i686-w64-mingw32-gcc
export CXX=i686-w64-mingw32-g++
export AR=i686-w64-mingw32-ar
export STRIP=i686-w64-mingw32-strip
# windres shells out to the preprocessor; the engine's ALLOCA_H define
# (-DALLOCA_H=<malloc.h>) turns into a shell redirect there. Wrap windres
# to drop it — resources never use it
cat > /tmp/windres-wrap <<'W'
#!/usr/bin/env python3
import os, sys
args = [a for a in sys.argv[1:] if not a.startswith("-DALLOCA_H")]
args = ["--preprocessor=i686-w64-mingw32-gcc",
        "--preprocessor-arg=-E", "--preprocessor-arg=-xc",
        "--preprocessor-arg=-DRC_INVOKED"] + args
os.execvp("i686-w64-mingw32-windres", ["i686-w64-mingw32-windres"] + args)
W
chmod +x /tmp/windres-wrap
export WINRC=/tmp/windres-wrap

mkdir -p /tmp/b/engine /tmp/b/hlsdk
( cd /src/xash3d-fwgs && tar cf - --exclude=./build . ) | tar xf - -C /tmp/b/engine
( cd /src/hlsdk-portable && tar cf - --exclude=./build . ) | tar xf - -C /tmp/b/hlsdk

echo "=== engine (win32 i686) ==="
cd /tmp/b/engine
# no --enable-all-renderers: gl4es doesn't build for PE targets and
# upstream Windows builds ship GL + software only anyway
./waf configure -T release --enable-lto --enable-bundled-deps \
    --enable-stbtt --sdl2=/opt/SDL2
./waf build
./waf install --destdir=/out

echo "=== game libraries (win32 i686) ==="
cd /tmp/b/hlsdk
./waf configure -T release
./waf build
./waf install --destdir=/out

echo "=== bundle SDL2 ==="
cp -av /opt/SDL2/i686-w64-mingw32/bin/SDL2.dll /out/

echo "container build done:"
ls -la /out
