#!/bin/bash
# Assemble a Steam Deck / Linux flatpak from the already-built linux-amd64
# tree (dist/linux-amd64). We package prebuilt binaries rather than compiling
# inside the flatpak SDK, so the bundle uses the exact engine we validated in
# the reproducible Docker build — and we don't need the multi-GB flatpak SDK
# on the build host, only the Platform runtime at bundle time.
#
# Output: dist/artifacts/continuum.flatpak  (single-file, side-loadable)
#
# Layout inside the flatpak (/app):
#   bin/xash3d            the engine
#   bin/continuum         launcher (sets RODIR + writable BASEDIR)
#   lib/*.so              engine support libs + bundled SDL2 (on LD_LIBRARY_PATH)
#   share/continuum/valve our read-only overlay: game .so libs + fonts/glyphs
# The player's game content + all writes live in the app's data dir (BASEDIR).
set -euo pipefail

APPID=org.continuum.HalfLife
ARCH=x86_64
RUNTIME_VERSION=25.08

cd "$(dirname "$0")/../.." || exit 1
ROOT=$PWD
DIST=$ROOT/dist
SRC=$DIST/linux-amd64
FP=$ROOT/tools/dist/flatpak

if [ ! -x "$SRC/xash3d" ]; then
	echo "[flatpak] dist/linux-amd64 not built yet — building it now"
	"$ROOT/tools/build_all.sh" linux-amd64
fi

for t in flatpak convert; do
	command -v "$t" >/dev/null || { echo "[flatpak] need '$t' on PATH"; exit 1; }
done

# the Platform runtime must be available to export against
if ! flatpak info "org.freedesktop.Platform/$ARCH/$RUNTIME_VERSION" >/dev/null 2>&1; then
	echo "[flatpak] installing runtime org.freedesktop.Platform//$RUNTIME_VERSION"
	flatpak install -y --noninteractive flathub \
		"org.freedesktop.Platform/$ARCH/$RUNTIME_VERSION" || {
		echo "[flatpak] could not install the runtime; install flathub first:"
		echo "  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
		exit 1
	}
fi

BUILD=$(mktemp -d)
REPO=$(mktemp -d)
trap 'rm -rf "$BUILD" "$REPO"' EXIT

APP=$BUILD/files
mkdir -p "$APP/bin" "$APP/lib" "$APP/share/continuum" \
	"$APP/share/applications" "$APP/share/icons/hicolor/256x256/apps"

# engine + support libs
cp "$SRC/xash3d" "$APP/bin/"
cp "$SRC"/*.so "$SRC"/*.so.* "$APP/lib/"
install -m755 "$FP/continuum.sh" "$APP/bin/continuum"

# read-only Continuum overlay: every game-lib + content folder the linux dist
# produced (valve, gearbox, bshift, hunger, ...) plus the always-mounted
# continuum/ assets. The linux dist is the single source of truth for what
# ships, so we copy ALL of its directories rather than naming them here — the
# engine binary, support libs and launcher are the only top-level *files* and
# were pulled into bin/lib above. Still NO game content: these dirs hold the
# .so libs (dlls/cl_dlls) + Continuum assets only.
for d in "$SRC"/*/; do
	cp -r "$d" "$APP/share/continuum/"
done

# desktop entry + icon (lambda mark, our own asset)
cp "$FP/$APPID.desktop" "$APP/share/applications/"
convert "$ROOT/redist/continuum/gfx/shell/continuum/lambda.png" \
	-resize 256x256 -background none -gravity center -extent 256x256 \
	"$APP/share/icons/hicolor/256x256/apps/$APPID.png"

# metadata (permissions live here since we don't run build-finish)
cat > "$BUILD/metadata" <<META
[Application]
name=$APPID
runtime=org.freedesktop.Platform/$ARCH/$RUNTIME_VERSION
sdk=org.freedesktop.Sdk/$ARCH/$RUNTIME_VERSION
command=continuum

[Context]
shared=network;ipc;
sockets=x11;fallback-x11;wayland;pulseaudio;
devices=all;
filesystems=home;
META

# host-visible exports (desktop + icon)
mkdir -p "$BUILD/export/share/applications" \
	"$BUILD/export/share/icons/hicolor/256x256/apps"
cp "$APP/share/applications/$APPID.desktop" "$BUILD/export/share/applications/"
cp "$APP/share/icons/hicolor/256x256/apps/$APPID.png" \
	"$BUILD/export/share/icons/hicolor/256x256/apps/"

echo "[flatpak] exporting to local repo"
flatpak build-export "$REPO" "$BUILD" >/dev/null

mkdir -p "$DIST/artifacts"
OUT=$DIST/artifacts/continuum.flatpak
echo "[flatpak] bundling -> $OUT"
flatpak build-bundle "$REPO" "$OUT" "$APPID"

echo "[flatpak] done: $OUT ($(du -h "$OUT" | cut -f1))"
echo "[flatpak] app id: $APPID   data dir on target: ~/.var/app/$APPID/data/valve"
