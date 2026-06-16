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

# NOTE: Windows is DEFERRED for the initial release (Steam Deck / amd64 Linux
# only); this container is kept working and ready. 32-bit (i686) is the agreed
# Windows target: a 32-bit engine can load mods' own SHIPPED 32-bit .dlls
# directly — the widest mod compatibility of any platform, and the one place
# closed-source / no-hlsdk-branch mods still run.

mkdir -p /tmp/b/engine
( cd /src/xash3d-fwgs && tar cf - --exclude=./build . ) | tar xf - -C /tmp/b/engine

echo "=== engine (win32 i686) ==="
cd /tmp/b/engine
# no --enable-all-renderers: gl4es doesn't build for PE targets and
# upstream Windows builds ship GL + software only anyway
./waf configure -T release --enable-lto --enable-bundled-deps \
    --enable-stbtt --sdl2=/opt/SDL2
./waf build
./waf install --destdir=/out

echo "=== game libraries (win32 i686) ==="
# Same branch loop as Linux (build-game-libs.sh). The MinGW toolchain exported
# above is inherited by the script; CONFIGURE_FLAGS has no -8 (32-bit) and the
# hlsdk build emits <name>.dll (no arch suffix), which the script's cp globs
# already handle. FUTURE: when Windows ships, decide whether to also fall back
# to mods' own shipped .dlls for branches we don't build ourselves.
CONFIGURE_FLAGS="-T release" OUT=/out \
    python3 /src/tools/dist/build-game-libs.py

echo "=== bundle SDL2 ==="
cp -av /opt/SDL2/i686-w64-mingw32/bin/SDL2.dll /out/

echo "container build done:"
ls -la /out
