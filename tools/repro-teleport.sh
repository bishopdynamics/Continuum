#!/bin/bash
# Repro harness for the map-change camera-slide (off-map view lerp on level
# transitions). Plays a demo back with cl_showerror visible and records it to an
# MP4 so we can read, at each changelevel, whether CL_CheckPredictionError took
# the snap branch ("player teleported: N units") or the arm branch ("prediction
# error: N units") — the latter, coincident with a visible slide, confirms the
# fix's single-frame first_frame guard was missed (hypothesis B).
#
# This is a DIAGNOSTIC reuse of tools/capture-demo.sh's startmovie->FIFO->ffmpeg
# pipeline, with two deliberate differences:
#   - developer 1 + cl_showerror 1   (CL_CheckPredictionError only prints when
#                                      cl_showerror.value && host_developer.value)
#   - con_notifytime kept HIGH        (capture-demo.sh sets it 0 for clean grabs;
#                                      we WANT the notify overlay on screen)
# cl_showerror only prints; it does not change the teleport/smoothing behavior.
#
# Usage:  tools/repro-teleport.sh [demo]      (default demo: tram_ride)
# Output: dist/media/repro-<demo>.mp4
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1   # repo root

DEMO=${1:-tram_ride}
GAME=${GAME:-valve}
WIDTH=${WIDTH:-1280}
HEIGHT=${HEIGHT:-720}
FPS=${FPS:-60}
FPS_CAP=${FPS_CAP:-60}
VSYNC=${VSYNC:-1}
OUTDIR=${OUTDIR:-dist/media}
LOG=dist-test/engine.log

command -v ffmpeg >/dev/null || { echo "missing required tool: ffmpeg" >&2; exit 1; }
[ -x dist-test/xash3d ] || { echo "engine not built — run tools/build-engine.sh first" >&2; exit 1; }
[ -f "demos/$DEMO.dem" ] || { echo "no demo at demos/$DEMO.dem" >&2; exit 1; }
mkdir -p "$OUTDIR"
OUT="$OUTDIR/repro-$DEMO.mp4"

ENGINE_PID=""; FFMPEG_PID=""; FIFO=""; DONECFG=""; DONECFG_BAK=""
cleanup() {
	[ -n "$FFMPEG_PID" ] && kill -INT "$FFMPEG_PID" 2>/dev/null && wait "$FFMPEG_PID" 2>/dev/null || true
	[ -n "$ENGINE_PID" ] && kill "$ENGINE_PID" 2>/dev/null || true
	if [ -n "$DONECFG_BAK" ]; then mv "$DONECFG_BAK" "$DONECFG"
	elif [ -n "$DONECFG" ] && [ -f "$DONECFG" ]; then rm "$DONECFG"; fi
	[ -n "$FIFO" ] && [ -p "$FIFO" ] && rm "$FIFO"
}
trap cleanup EXIT INT TERM

# stage the demo into the gamedir so playdemo finds it
cp "demos/$DEMO.dem" "dist-test/$GAME/$DEMO.dem"

# force capture resolution (window is born from these RENDERINFO cvars)
vidcfg="dist-test/$GAME/unified_video.cfg"
[ -f "$vidcfg" ] || vidcfg="dist-test/valve/unified_video.cfg"
if [ -f "$vidcfg" ]; then
	for kv in "width=$WIDTH" "height=$HEIGHT"; do
		c=${kv%=*}; v=${kv#*=}
		if grep -qE "^$c \"" "$vidcfg"; then sed -i "s/^$c \"[^\"]*\"/$c \"$v\"/" "$vidcfg"
		else printf '%s "%s"\n' "$c" "$v" >> "$vidcfg"; fi
	done
fi

FIFO=$(mktemp -u --suffix=.rawvideo); mkfifo "$FIFO"

# exec'd by the engine once the campaign streaming preload drains (same hook
# capture-demo.sh uses). developer 1 + cl_showerror 1 reveal the prediction
# branch; con_notifytime 8 keeps the overlay up ~8s so it lingers across each
# transition. cl_showerror lines use Con_NPrintf (idx 10-13) — top-left overlay.
DONECFG="dist-test/$GAME/streampreload_done.cfg"
[ -f "$DONECFG" ] && { DONECFG_BAK="$DONECFG.reprobak"; cp "$DONECFG" "$DONECFG_BAK"; }
printf '// temporary — tools/repro-teleport.sh, removed after.\ndeveloper 1\ncl_showerror 1\ncon_notifytime 8\nstartmovie "%s"\nplaydemo %s\n' \
	"$FIFO" "$DEMO" > "$DONECFG"

echo ">> launching $GAME, warming campaign, recording $DEMO at ${WIDTH}x${HEIGHT} (cl_showerror on)..."
./play-continuum.sh "$GAME" -console -windowed -nowriteconfig -width "$WIDTH" -height "$HEIGHT" \
	+fps_max "$FPS_CAP" +gl_vsync "$VSYNC" +snd_mute_losefocus 0 >/dev/null 2>&1 &
ENGINE_PID=$!

# CPU encoder (libx264): always works, no GPU probe. Frames arrive bottom-up RGBA.
FFLOG=/tmp/repro-ffmpeg.log
ffmpeg -hide_banner -loglevel verbose -y \
	-f rawvideo -pixel_format rgba -video_size "${WIDTH}x${HEIGHT}" -framerate "$FPS" \
	-thread_queue_size 1024 -i "$FIFO" \
	-vf vflip -c:v libx264 -crf 16 -preset veryfast -pix_fmt yuv420p \
	-movflags +faststart "$OUT" 2>"$FFLOG" &
FFMPEG_PID=$!

# wait for playback to start (markers are Con_Printf -> engine.log under -console)
waited=0
until grep -qF "Demo playback started" "$LOG" 2>/dev/null; do
	sleep 0.25; waited=$((waited+1))
	[ "$waited" -ge 480 ] && { echo "demo never started (timeout)" >&2; exit 1; }
	kill -0 "$ENGINE_PID" 2>/dev/null || { echo "engine exited early" >&2; exit 1; }
done
echo ">> recording..."

until grep -qF "Demo playback ended" "$LOG" 2>/dev/null; do
	kill -0 "$FFMPEG_PID" 2>/dev/null || { echo "ffmpeg exited during capture" >&2; break; }
	kill -0 "$ENGINE_PID" 2>/dev/null || { echo "engine exited during capture" >&2; break; }
	sleep 0.25
done

for _ in $(seq 1 8); do kill -0 "$FFMPEG_PID" 2>/dev/null || break; sleep 0.25; done
kill -INT "$FFMPEG_PID" 2>/dev/null || true; wait "$FFMPEG_PID" 2>/dev/null || true; FFMPEG_PID=""
kill "$ENGINE_PID" 2>/dev/null || true; wait "$ENGINE_PID" 2>/dev/null || true; ENGINE_PID=""
cleanup
echo ">> done: $OUT ($(du -h "$OUT" 2>/dev/null | cut -f1))"
