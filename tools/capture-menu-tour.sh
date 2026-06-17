#!/bin/bash
# Capture a SCRIPTED tour of the Continuum menu to a GIF for the README.
#
# Unlike tools/capture-menu-gif.sh (a hand-driven fixed-length grab), this drives
# the menu from a text script so re-shoots are identical and the GIF is exactly as
# long as the tour. The script is run by the engine's `ui_tour` command (menus/
# continuum/Tour.cpp); navigation targets buttons by their on-screen text:
#
#     wait 8000
#     mark rec_start          # capture begins at this marker
#     click "Configuration"
#     wait 1500
#     back
#     wait 1000
#     mark rec_stop           # capture ends at this marker
#
# Verbs: wait <ms> | click "<label>" | focus "<label>" | key <name> | back |
#        mark <label>   (see menus/continuum/Tour.cpp for the full reference)
#
# Recording is bracketed by two markers the tour prints to stdout:
#   mark rec_start  -> ffmpeg starts
#   mark rec_stop   -> ffmpeg stops   (or the engine's "[ui_tour] DONE")
# So put a trailing `wait 2000` before `mark rec_stop` for a settle tail.
#
# Tours live in menu-tours/<name>.txt; the GIF is written to doc/media/<name>.gif,
# always matching the tour's filename.
#
# Usage:
#   tools/capture-menu-tour.sh [name]
#     name   tour name (no path, no extension) -> menu-tours/<name>.txt,
#            output doc/media/<name>.gif. Default: menu-tour
#
#   tools/capture-menu-tour.sh                  # menu-tours/menu-tour.txt
#   tools/capture-menu-tour.sh my-special-tour  # menu-tours/my-special-tour.txt
#
# Env overrides (same as capture-menu-gif.sh):
#   GAME=valve  WIDTH=1280  HEIGHT=720   GIF_FPS=15  GIF_WIDTH=640
#   FPS_CAP=60  VSYNC=1     TOUR_DIR=menu-tours  OUT_DIR=doc/media  OUT=<path>
#   RUN_LOG=dist/<name>.tour.log   (engine output incl. the [ui_tour] trace)
#   START_TIMEOUT=60  STOP_TIMEOUT=180   (seconds to wait for the markers)
#
# Requires: ffmpeg (with x11grab), xwininfo, an X11 session ($DISPLAY).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1   # repo root

# the single argument is the tour NAME (no path, no extension); default "menu-tour".
# tours live in menu-tours/<name>.txt and the GIF lands in doc/media/<name>.gif,
# so the output always matches the tour filename.
NAME=$(basename "${1:-menu-tour}" .txt)
TOUR_DIR=${TOUR_DIR:-menu-tours}
OUT_DIR=${OUT_DIR:-doc/media}
SCRIPT="$TOUR_DIR/$NAME.txt"
GAME=${GAME:-valve}
WIDTH=${WIDTH:-1280}
HEIGHT=${HEIGHT:-720}
GIF_FPS=${GIF_FPS:-8}
GIF_WIDTH=${GIF_WIDTH:-640}
FPS_CAP=${FPS_CAP:-60}
VSYNC=${VSYNC:-1}
OUT=${OUT:-$OUT_DIR/${NAME}.gif}
DISPLAY=${DISPLAY:-:0}
START_TIMEOUT=${START_TIMEOUT:-60}
STOP_TIMEOUT=${STOP_TIMEOUT:-180}

[ -f "$SCRIPT" ] || { echo "tour script not found: $SCRIPT (tours live in $TOUR_DIR/<name>.txt)" >&2; exit 1; }

# pre-check the tour for typos (unknown verb/key, bad args, missing markers) so a
# mistake fails here instead of silently doing nothing in the engine.
LINT="$(dirname "$0")/lint-menu-tour.py"
if [ -f "$LINT" ] && command -v python3 >/dev/null; then
	python3 "$LINT" "$SCRIPT" || { echo "tour lint failed — fix the script above and retry" >&2; exit 1; }
fi
for tool in ffmpeg xwininfo; do
	command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done
[ -x dist-test/xash3d ] || { echo "engine not built — run tools/build-engine.sh first" >&2; exit 1; }
[ -d "dist-test/$GAME" ] || { echo "no game at dist-test/$GAME" >&2; exit 1; }

# the engine loads the tour from its own filesystem (game search path), so stage
# the script into the gamedir under a fixed name and run `+ui_tour tour_run.txt`.
cp "$SCRIPT" "dist-test/$GAME/tour_run.txt"

# window title = the game's title (engine sets SDL caption to GI->title).
TITLE=$(grep -iE '^\s*title\b' "dist-test/$GAME/gameinfo.txt" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
[ -n "$TITLE" ] || TITLE=$(grep -iE '^\s*game\b' "dist-test/$GAME/liblist.gam" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
[ -n "$TITLE" ] || TITLE="Half-Life"

mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp --suffix=.mkv)
PAL=$(mktemp --suffix=.png)

# keep the engine output (incl. the [ui_tour] action trace) at a stable, gitignored
# path so it can be reviewed after a capture. Default dist/<name>.tour.log; the
# engine also writes its own dist-test/engine.log for manual `ui_tour` runs.
LOG=${RUN_LOG:-dist/${NAME}.tour.log}
mkdir -p "$(dirname "$LOG")"

ENGINE_PID=""
FFMPEG_PID=""
cleanup() {
	[ -n "$FFMPEG_PID" ] && kill "$FFMPEG_PID" 2>/dev/null || true
	[ -n "$ENGINE_PID" ] && kill "$ENGINE_PID" 2>/dev/null || true
	[ -f "$TMP" ] && rm "$TMP"
	[ -f "$PAL" ] && rm "$PAL"
}
trap cleanup EXIT INT TERM

# block until $1 (an ERE) appears in the engine log, or $2 seconds elapse.
# returns 0 if matched, 1 on timeout.
wait_marker() {
	timeout "$2" grep -m1 -E "$1" <(tail -n +1 -f "$LOG" 2>/dev/null) >/dev/null
}

echo "launching $GAME menu at ${WIDTH}x${HEIGHT}, tour: $SCRIPT"
./play-continuum.sh "$GAME" -windowed -width "$WIDTH" -height "$HEIGHT" \
	+fps_max "$FPS_CAP" +gl_vsync "$VSYNC" +ui_tour tour_run.txt >"$LOG" 2>&1 &
ENGINE_PID=$!

echo "waiting for window \"$TITLE\"..."
geom=""
for _ in $(seq 1 120); do
	if geom=$(xwininfo -display "$DISPLAY" -name "$TITLE" 2>/dev/null); then break; fi
	sleep 0.25
	kill -0 "$ENGINE_PID" 2>/dev/null || { echo "engine exited before window appeared" >&2; sed 's/^/  | /' "$LOG" | tail -20 >&2; exit 1; }
done
[ -n "$geom" ] || { echo "window \"$TITLE\" never appeared" >&2; exit 1; }

X=$(awk '/Absolute upper-left X/{print $NF}' <<<"$geom")
Y=$(awk '/Absolute upper-left Y/{print $NF}' <<<"$geom")
W=$(awk '/^  Width:/{print $NF}'  <<<"$geom")
H=$(awk '/^  Height:/{print $NF}' <<<"$geom")
echo "window at +${X},${Y} ${W}x${H}"
command -v wmctrl >/dev/null && wmctrl -a "$TITLE" 2>/dev/null || true

# rec_start is the real go-signal: it both proves the tour loaded+ran and marks
# where recording begins. (The earlier "loaded N steps" line is printed before the
# engine's stdout console is live, so it never reaches us — don't gate on it.)
echo "waiting for 'mark rec_start' (<= ${START_TIMEOUT}s)..."
if ! wait_marker '\[ui_tour\] MARK rec_start' "$START_TIMEOUT"; then
	echo "no rec_start marker — tour didn't run. Check the script has 'mark rec_start'," >&2
	echo "that labels match the on-screen text, and that this build has ui_tour:" >&2
	sed 's/^/  | /' "$LOG" | grep -iE "ui_tour|unknown command" >&2 || echo "  | (no ui_tour output at all)" >&2
	exit 1
fi

echo "recording (until 'mark rec_stop' / DONE, <= ${STOP_TIMEOUT}s)..."
# single lossless grab; -draw_mouse 0 (controller-first menu has no cursor),
# -nostdin so ffmpeg doesn't fight us for the terminal. No -t: we stop on marker.
ffmpeg -hide_banner -loglevel warning -y -nostdin \
	-f x11grab -draw_mouse 0 -thread_queue_size 1024 \
	-framerate "$GIF_FPS" -video_size "${W}x${H}" -i "${DISPLAY}+${X},${Y}" \
	-t "$STOP_TIMEOUT" -c:v ffv1 "$TMP" &
FFMPEG_PID=$!

wait_marker '\[ui_tour\] (MARK rec_stop|DONE)' "$STOP_TIMEOUT" || \
	echo "warning: rec_stop/DONE not seen within ${STOP_TIMEOUT}s; stopping anyway" >&2

# stop the grab gracefully so ffmpeg writes a valid trailer
kill -INT "$FFMPEG_PID" 2>/dev/null || true
wait "$FFMPEG_PID" 2>/dev/null || true
FFMPEG_PID=""

# drop the engine
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

# surface the tour action trace and where the full run log lives
echo "tour trace:"
grep -aE "\[ui_tour\]" "$LOG" | sed 's/^/  /' || true
echo "full run log: $LOG"
