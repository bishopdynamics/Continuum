#!/bin/bash
# Capture a hand-driven tour of the Continuum menu to a GIF for the README.
#
# No demo can drive the menu, so navigation is a manual take: the script just
# standardizes the window size and the encode so re-shoots look identical. It
# launches the engine to the menu, waits for you to press Enter, grabs a fixed
# number of seconds while you navigate, then builds the GIF.
#
# The GIF is built in two passes (palettegen -> paletteuse) from a SINGLE
# lossless grab — grabbing twice would capture two different navigations.
#
# Output: doc/media/menu-tour.gif (committed; kept small via fps + scale).
#
# Usage:
#   tools/capture-menu-gif.sh
#
# Env overrides:
#   GAME=valve  WIDTH=1280  HEIGHT=720   (engine window)
#   DURATION=30   GIF_FPS=10   GIF_WIDTH=640   (capture + GIF size)
#                 (GIF_FPS must evenly divide FPS_CAP — 60/10=6 — so each grab
#                  lands on a complete game frame, not a half-presented one)
#   FPS_CAP=60   (caps the engine's render rate during the grab — uncapped fps
#                 tears badly under x11grab)
#   VSYNC=1      (force gl_vsync on during the grab — also kills tearing;
#                 persists to config afterwards, which is fine)
#   OUT=doc/media/menu-tour.gif
#
# Requires: ffmpeg (with x11grab), xwininfo, an X11 session ($DISPLAY).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1   # repo root

GAME=${GAME:-valve}
WIDTH=${WIDTH:-1280}
HEIGHT=${HEIGHT:-720}
DURATION=${DURATION:-60}
GIF_FPS=${GIF_FPS:-10}
GIF_WIDTH=${GIF_WIDTH:-640}
FPS_CAP=${FPS_CAP:-60}
VSYNC=${VSYNC:-1}
OUT=${OUT:-doc/media/menu-tour.gif}
DISPLAY=${DISPLAY:-:0}

for tool in ffmpeg xwininfo; do
	command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done
[ -x install/xash3d ] || { echo "engine not built — run tools/build-engine.sh first" >&2; exit 1; }

# window title = the game's title (engine sets SDL caption to GI->title).
# `|| true`: missing file / no match must not trip `set -e` (valve has no
# gameinfo.txt — it uses liblist.gam).
TITLE=$(grep -iE '^\s*title\b' "install/$GAME/gameinfo.txt" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
[ -n "$TITLE" ] || TITLE=$(grep -iE '^\s*game\b' "install/$GAME/liblist.gam" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
[ -n "$TITLE" ] || TITLE="Half-Life"

mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp --suffix=.mkv)
PAL=$(mktemp --suffix=.png)

ENGINE_PID=""
cleanup() {
	[ -n "$ENGINE_PID" ] && kill "$ENGINE_PID" 2>/dev/null || true
	[ -f "$TMP" ] && rm "$TMP"
	[ -f "$PAL" ] && rm "$PAL"
}
trap cleanup EXIT INT TERM

echo "launching $GAME menu at ${WIDTH}x${HEIGHT} (fps_max $FPS_CAP, vsync $VSYNC)..."
./play-continuum.sh "$GAME" -windowed -width "$WIDTH" -height "$HEIGHT" \
	+fps_max "$FPS_CAP" +gl_vsync "$VSYNC" >/dev/null 2>&1 &
ENGINE_PID=$!

echo "waiting for window \"$TITLE\"..."
geom=""
for _ in $(seq 1 120); do
	if geom=$(xwininfo -display "$DISPLAY" -name "$TITLE" 2>/dev/null); then break; fi
	sleep 0.25
	kill -0 "$ENGINE_PID" 2>/dev/null || { echo "engine exited before window appeared" >&2; exit 1; }
done
[ -n "$geom" ] || { echo "window \"$TITLE\" never appeared" >&2; exit 1; }

X=$(awk '/Absolute upper-left X/{print $NF}' <<<"$geom")
Y=$(awk '/Absolute upper-left Y/{print $NF}' <<<"$geom")
W=$(awk '/^  Width:/{print $NF}'  <<<"$geom")
H=$(awk '/^  Height:/{print $NF}' <<<"$geom")
echo "window at +${X},${Y} ${W}x${H}"
command -v wmctrl >/dev/null && wmctrl -a "$TITLE" 2>/dev/null || true

# hand-driven take: let James get the menu ready, then grab a fixed window
echo
echo "Bring the menu to the foreground and get ready to navigate."
read -rp "Press Enter to start a ${DURATION}s capture... " _
for n in 3 2 1; do echo "  $n..."; sleep 1; done
echo "recording ${DURATION}s — navigate now!"

# single lossless grab of exactly the window region.
# -thread_queue_size: don't starve the grabber while ffv1 writes;
# -draw_mouse 0: the controller-first menu has no cursor to show.
ffmpeg -hide_banner -loglevel warning -y \
	-f x11grab -draw_mouse 0 -thread_queue_size 1024 \
	-framerate "$GIF_FPS" -video_size "${W}x${H}" -i "${DISPLAY}+${X},${Y}" \
	-t "$DURATION" -c:v ffv1 "$TMP"

# done capturing — drop the engine
kill "$ENGINE_PID" 2>/dev/null || true
wait "$ENGINE_PID" 2>/dev/null || true
ENGINE_PID=""

# two-pass GIF: build an optimized palette, then apply it
echo "encoding GIF..."
FILTERS="fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos"
ffmpeg -hide_banner -loglevel warning -y -i "$TMP" \
	-vf "${FILTERS},palettegen=stats_mode=diff" "$PAL"
ffmpeg -hide_banner -loglevel warning -y -i "$TMP" -i "$PAL" \
	-lavfi "${FILTERS} [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=3" "$OUT"

echo "done: $OUT ($(du -h "$OUT" | cut -f1))"
