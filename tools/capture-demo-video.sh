#!/bin/bash
# Capture a recorded demo to an MP4 by playing it back on the streaming engine
# and screen-grabbing the window with ffmpeg (x11grab). This is the
# re-capturable pipeline: dem in -> video out, one command. Re-run it after
# re-recording the demo or after changing graphics settings.
#
# The grab is bracketed by two engine log markers so the video is exactly the
# demo, with no menu flash or trailing footage:
#   start: "Demo playback started"   end: "Demo playback ended"
# (both are Con_Printfs added to the engine: CL_DemoStartPlayback / CL_DemoCompleted.)
#
# Encodes straight to H.264 with the GPU (NVENC) in real time — no lossless
# intermediate, no slow CPU transcode. Set ENCODER=libx264 for a CPU fallback.
#
# Output: dist/<demo>.mp4 (dist/ is gitignored — a release asset, NOT committed;
# copyrighted gameplay). e.g. demo "cascade" -> dist/cascade.mp4.
#
# Usage:
#   tools/capture-demo-video.sh [demo]
#
#   demo   demo name under demos/<demo>.dem (default: cascade); the output is
#          named to match (dist/<demo>.mp4)
#
# Env overrides:
#   GAME=valve  WIDTH=1280  HEIGHT=720  FPS=60   (FPS should equal FPS_CAP)
#   FPS_CAP=60   (caps the engine's render rate during the grab — uncapped fps
#                 tears badly under x11grab)
#   VSYNC=1      (force gl_vsync on during the grab — also kills tearing;
#                 persists to config afterwards, which is fine)
#   PRELOAD=1    (let the campaign streaming preload finish at the menu, then
#                 load the demo's first map, then start playback — so the whole
#                 run is warm and transitions are seamless. A cold +playdemo
#                 renders the world wrong and skips the preload. PRELOAD=0
#                 disables, reverting to a plain +playdemo.)
#   SETTLE=0.6   (seconds to wait after playback starts before grabbing)
#   ENCODER=h264_nvenc  CQ=19  NVENC_PRESET=p6   (GPU encode; CQ lower = better)
#   ENCODER=libx264     CRF=18 PRESET=slow       (CPU fallback)
#   OUT=dist/<demo>.mp4   (override the output path)
#
# Requires: ffmpeg (x11grab + the chosen encoder), xwininfo, an X11 session.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1   # repo root

DEMO=${1:-cascade}
GAME=${GAME:-valve}
WIDTH=${WIDTH:-1280}
HEIGHT=${HEIGHT:-720}
FPS=${FPS:-60}    # match FPS_CAP 1:1 — resampling (e.g. 30 of 60) judders/tears
FPS_CAP=${FPS_CAP:-60}
VSYNC=${VSYNC:-1}
ENCODER=${ENCODER:-h264_nvenc}   # GPU encode; set ENCODER=libx264 for CPU
CQ=${CQ:-19}                     # NVENC constant quality (lower = better)
NVENC_PRESET=${NVENC_PRESET:-p6} # p1 fastest .. p7 best
CRF=${CRF:-18}                   # libx264 fallback quality
PRESET=${PRESET:-slow}           # libx264 fallback preset
PRELOAD=${PRELOAD:-1}
SETTLE=${SETTLE:-0.6}
OUT=${OUT:-dist/${DEMO}.mp4}
DISPLAY=${DISPLAY:-:0}

# encoder options: NVENC encodes in real time, so we grab straight to the final
# MP4 — no lossless intermediate, no slow CPU transcode.
if [[ "$ENCODER" == *nvenc* ]]; then
	VOPTS=(-c:v "$ENCODER" -preset "$NVENC_PRESET" -rc vbr -cq "$CQ" -b:v 0)
else
	VOPTS=(-c:v "$ENCODER" -crf "$CRF" -preset "$PRESET")
fi

# --- preflight -------------------------------------------------------------
for tool in ffmpeg xwininfo; do
	command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done
[ -x install/xash3d ] || { echo "engine not built — run tools/build-engine.sh first" >&2; exit 1; }
[ -f "demos/$DEMO.dem" ] || { echo "no demo at demos/$DEMO.dem" >&2; exit 1; }

# window title = the game's title (engine sets SDL caption to GI->title).
# `|| true`: missing file / no match must not trip `set -e` (valve has no
# gameinfo.txt — it uses liblist.gam).
TITLE=$(grep -iE '^\s*title\b' "install/$GAME/gameinfo.txt" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
[ -n "$TITLE" ] || TITLE=$(grep -iE '^\s*game\b' "install/$GAME/liblist.gam" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
[ -n "$TITLE" ] || TITLE="Half-Life"

LOG=install/engine.log
mkdir -p "$(dirname "$OUT")"

# stage the demo into the gamedir so playdemo finds it
cp "demos/$DEMO.dem" "install/$GAME/$DEMO.dem"

# PRELOAD flow: let the campaign streaming preload finish at the menu, THEN start
# playback, so the first map is already resident (fixes the cold-start world) and
# transitions are seamless. We can't use +playdemo for this: stuffcmds PREPENDS
# commandline +cmds ahead of the queued world_preloads, so the demo would start
# before any preload. Instead we drop a temp streampreload_done.cfg that the
# engine execs once the world_preload queue has fully drained (a hook added to
# Host_QueueStreamPreload). It runs `playdemo` — NOT `map`: a `map` server-load
# after a full preload crashes in the game DLL (CWorld::Precache, "late precache"
# state bug); demo playback is client-side and never touches that path.
DONECFG=""
DONECFG_BAK=""
if [ "$PRELOAD" = 1 ]; then
	DONECFG="install/$GAME/streampreload_done.cfg"
	[ -f "$DONECFG" ] && { DONECFG_BAK="$DONECFG.capbak"; cp "$DONECFG" "$DONECFG_BAK"; }
	printf '// temporary — tools/capture-demo-video.sh, removed after.\nplaydemo %s\n' "$DEMO" > "$DONECFG"
fi

ENGINE_PID=""
FFMPEG_PID=""
cleanup() {
	[ -n "$FFMPEG_PID" ] && kill -INT "$FFMPEG_PID" 2>/dev/null && wait "$FFMPEG_PID" 2>/dev/null || true
	[ -n "$ENGINE_PID" ] && kill "$ENGINE_PID" 2>/dev/null || true
	if [ -n "$DONECFG" ]; then
		if [ -n "$DONECFG_BAK" ]; then mv "$DONECFG_BAK" "$DONECFG"
		elif [ -f "$DONECFG" ]; then rm "$DONECFG"; fi
	fi
}
trap cleanup EXIT INT TERM

# wait for a log marker to appear (after the log is freshly truncated on launch)
wait_for_marker() {
	local marker=$1 timeout=$2 waited=0
	while ! grep -qF "$marker" "$LOG" 2>/dev/null; do
		sleep 0.25; waited=$((waited + 1))
		[ "$waited" -ge $((timeout * 4)) ] && return 1
		kill -0 "$ENGINE_PID" 2>/dev/null || { echo "engine exited early" >&2; return 1; }
	done
}

# --- launch playback -------------------------------------------------------
# PRELOAD: boot clean to the menu (no +playdemo) so the campaign preload drains
# first; streampreload_done.cfg then fires playdemo. Otherwise go straight to
# +playdemo (world may render wrong + transitions rough — preload skipped).
if [ -n "$DONECFG" ]; then
	echo "launching $GAME, warming campaign at menu then playing demo $DEMO at ${WIDTH}x${HEIGHT}..."
	START=()
else
	echo "launching $GAME, playing $DEMO at ${WIDTH}x${HEIGHT}..."
	START=(+playdemo "$DEMO")
fi
./play-continuum.sh "$GAME" -windowed -width "$WIDTH" -height "$HEIGHT" \
	+fps_max "$FPS_CAP" +gl_vsync "$VSYNC" ${START[@]+"${START[@]}"} >/dev/null 2>&1 &
ENGINE_PID=$!

# locate the window (it maps around engine init) and read its on-screen rect
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

# raise it so nothing overlaps the grab region (best-effort)
command -v wmctrl >/dev/null && wmctrl -a "$TITLE" 2>/dev/null || true

# wait until the demo actually starts rendering, then grab until it completes
echo "waiting for demo playback to start..."
wait_for_marker "Demo playback started" 60 || { echo "demo never started" >&2; exit 1; }
sleep "$SETTLE"   # let playback's first frame settle on the resident world

# grab straight to the final MP4 (NVENC keeps up in real time).
# -thread_queue_size: keep the x11grab input buffered; -draw_mouse 0: no cursor.
echo "recording -> $OUT ($ENCODER)..."
ffmpeg -hide_banner -loglevel warning -y \
	-f x11grab -draw_mouse 0 -thread_queue_size 1024 \
	-framerate "$FPS" -video_size "${W}x${H}" -i "${DISPLAY}+${X},${Y}" \
	"${VOPTS[@]}" -pix_fmt yuv420p -movflags +faststart "$OUT" &
FFMPEG_PID=$!

# stop the moment the demo finishes (engine prints "Demo playback ended")
wait_for_marker "Demo playback ended" 1800 || echo "warning: end marker not seen; stopping anyway" >&2
kill -INT "$FFMPEG_PID" 2>/dev/null || true
wait "$FFMPEG_PID" 2>/dev/null || true
FFMPEG_PID=""

# quit the engine (back at the menu after playback)
kill "$ENGINE_PID" 2>/dev/null || true
wait "$ENGINE_PID" 2>/dev/null || true
ENGINE_PID=""

trap - EXIT INT TERM
echo "done: $OUT ($(du -h "$OUT" | cut -f1))"
