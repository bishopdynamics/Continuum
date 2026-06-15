#!/bin/bash
# Capture a recorded demo to an MP4 by playing it back on the streaming engine
# and dumping each rendered frame straight from the engine (no screen grab).
# This is the re-capturable pipeline: dem in -> video out, one command.
#
# How it works: the engine's `startmovie <fifo>` writes the raw RGBA backbuffer
# of every rendered frame to a FIFO (glReadPixels — no compositor, no async
# screen read, so no tearing). ffmpeg reads that FIFO as rawvideo, captures the
# game audio from PulseAudio in parallel, and encodes to H.264 (NVENC). The demo
# ending auto-stops the movie (engine closes the FIFO -> ffmpeg sees EOF).
#
# Frames are bottom-up (glReadPixels order); ffmpeg flips with -vf vflip.
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
#   GAME=valve  WIDTH=1280  HEIGHT=720  FPS=60
#             WIDTH/HEIGHT are written into unified_video.cfg and PERSIST — the
#             game stays at the capture resolution afterwards. FPS must match the
#             render rate (FPS_CAP) so the timeline is right.
#   FPS_CAP=60   (caps the engine's render rate; FPS should equal it)
#   VSYNC=1      (gl_vsync during capture; paces rendering to a steady 60)
#   PRELOAD=1    (warm the whole campaign at the menu before playback, so the
#                 first map is resident and transitions are seamless; PRELOAD=0
#                 reverts to a plain +playdemo with a cold first map)
#   ENCODER=h264_nvenc  CQ=19  NVENC_PRESET=p6   (GPU encode; CQ lower = better)
#   ENCODER=libx264     CRF=18 PRESET=slow       (CPU fallback)
#   AUDIO=1   AUDIO_DEV=<src>   ABITRATE=192k    (capture game audio; AUDIO=0
#             off. default source = the default sink's .monitor via pactl)
#   OUT=dist/<demo>.mp4   (override the output path)
#
# Requires: ffmpeg (rawvideo + the chosen encoder), the movie-capable engine
# (startmovie/endmovie), and an audio server reachable via pactl for sound.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1   # repo root

DEMO=${1:-cascade}
GAME=${GAME:-valve}
WIDTH=${WIDTH:-1280}
HEIGHT=${HEIGHT:-720}
FPS=${FPS:-60}
FPS_CAP=${FPS_CAP:-60}
VSYNC=${VSYNC:-1}
ENCODER=${ENCODER:-h264_nvenc}   # GPU encode; set ENCODER=libx264 for CPU
CQ=${CQ:-19}                     # NVENC constant quality (lower = better)
NVENC_PRESET=${NVENC_PRESET:-p6} # p1 fastest .. p7 best
CRF=${CRF:-18}                   # libx264 fallback quality
PRESET=${PRESET:-slow}           # libx264 fallback preset
PRELOAD=${PRELOAD:-1}
AUDIO=${AUDIO:-1}                # capture game audio too (PulseAudio/PipeWire)
AUDIO_DEV=${AUDIO_DEV:-}         # override the capture source (default: auto)
ABITRATE=${ABITRATE:-192k}
OUT=${OUT:-dist/${DEMO}.mp4}

# video encoder options
if [[ "$ENCODER" == *nvenc* ]]; then
	VOPTS=(-c:v "$ENCODER" -preset "$NVENC_PRESET" -rc vbr -cq "$CQ" -b:v 0)
else
	VOPTS=(-c:v "$ENCODER" -crf "$CRF" -preset "$PRESET")
fi

# audio: capture the monitor of the default output sink (= what the game plays).
AUDIO_IN=()
AUDIO_MAP=()
SNDARGS=()   # extra engine args needed to actually produce audio
MON=""
if [ "$AUDIO" = 1 ]; then
	MON="$AUDIO_DEV"
	if [ -z "$MON" ] && command -v pactl >/dev/null; then
		sink=$(pactl get-default-sink 2>/dev/null || true)
		[ -n "$sink" ] && MON="${sink}.monitor"
	fi
	if [ -n "$MON" ]; then
		AUDIO_IN=(-f pulse -thread_queue_size 1024 -i "$MON")
		# NO -shortest: if the pulse monitor EOFs early (it intermittently gives
		# only a fraction of a second), -shortest would truncate the whole video
		# to that. Without it, video encodes to the end; ffmpeg exits when both
		# the FIFO (demo end) and audio inputs are done, else the script SIGINTs.
		AUDIO_MAP=(-map 0:v -map 1:a -c:a aac -b:a "$ABITRATE")
		# the engine mutes audio when the window loses focus (snd_mute_losefocus,
		# default 1); an automated capture never holds focus, so disable it.
		SNDARGS=(+snd_mute_losefocus 0)
	else
		echo "warning: no audio source (need pactl or AUDIO_DEV=); capturing video only" >&2
	fi
fi

# --- preflight -------------------------------------------------------------
command -v ffmpeg >/dev/null || { echo "missing required tool: ffmpeg" >&2; exit 1; }
[ -x install/xash3d ] || { echo "engine not built — run tools/build-engine.sh first" >&2; exit 1; }
[ -f "demos/$DEMO.dem" ] || { echo "no demo at demos/$DEMO.dem" >&2; exit 1; }

LOG=install/engine.log
mkdir -p "$(dirname "$OUT")"

# stage the demo into the gamedir so playdemo finds it
cp "demos/$DEMO.dem" "install/$GAME/$DEMO.dem"

# FIFO the engine streams raw frames into and ffmpeg reads from
FIFO=$(mktemp -u --suffix=.rawvideo)
mkfifo "$FIFO"

# PRELOAD: let the campaign streaming preload finish at the menu, THEN start
# playback (first map resident, seamless transitions). A commandline +cmd is
# prepended ahead of the queued world_preloads, so instead we drop a temp
# streampreload_done.cfg the engine execs once the preload queue drains (a hook
# in Host_QueueStreamPreload). It runs `startmovie <fifo>` then `playdemo`.
DONECFG=""
DONECFG_BAK=""
if [ "$PRELOAD" = 1 ]; then
	DONECFG="install/$GAME/streampreload_done.cfg"
	[ -f "$DONECFG" ] && { DONECFG_BAK="$DONECFG.capbak"; cp "$DONECFG" "$DONECFG_BAK"; }
	printf '// temporary — tools/capture-demo-video.sh, removed after.\nstartmovie "%s"\nplaydemo %s\n' \
		"$FIFO" "$DEMO" > "$DONECFG"
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
	[ -p "$FIFO" ] && rm "$FIFO"
}
trap cleanup EXIT INT TERM

# wait for a log marker (the log is freshly truncated on launch)
wait_for_marker() {
	local marker=$1 timeout=$2 waited=0
	while ! grep -qF "$marker" "$LOG" 2>/dev/null; do
		sleep 0.25; waited=$((waited + 1))
		[ "$waited" -ge $((timeout * 4)) ] && return 1
		kill -0 "$ENGINE_PID" 2>/dev/null || { echo "engine exited early" >&2; return 1; }
	done
}

# force the capture resolution. The window is born from the width/height
# RENDERINFO cvars; unified_video.cfg re-applies them after the -width/-height
# cmdline, so set them there directly (persists; the game stays at this res).
VIDCFG="install/$GAME/unified_video.cfg"
[ -f "$VIDCFG" ] || VIDCFG="install/valve/unified_video.cfg"
if [ -f "$VIDCFG" ]; then
	for kv in "width=$WIDTH" "height=$HEIGHT"; do
		c=${kv%=*}; v=${kv#*=}
		if grep -qE "^$c \"" "$VIDCFG"; then
			sed -i "s/^$c \"[^\"]*\"/$c \"$v\"/" "$VIDCFG"
		else
			printf '%s "%s"\n' "$c" "$v" >> "$VIDCFG"
		fi
	done
else
	echo "warning: no unified_video.cfg; render size may not match ${WIDTH}x${HEIGHT}" >&2
fi

# --- launch ----------------------------------------------------------------
# Boot clean to the menu; streampreload_done.cfg fires startmovie + playdemo once
# the campaign is warm. (PRELOAD=0: plain +playdemo, no startmovie -> no capture,
# so PRELOAD must be on for movie capture.)
if [ -n "$DONECFG" ]; then
	echo "launching $GAME, warming campaign then capturing demo $DEMO at ${WIDTH}x${HEIGHT}..."
	START=()
else
	echo "PRELOAD=0 has no startmovie hook; cannot capture. Set PRELOAD=1." >&2
	exit 1
fi
./play-continuum.sh "$GAME" -windowed -width "$WIDTH" -height "$HEIGHT" \
	+fps_max "$FPS_CAP" +gl_vsync "$VSYNC" ${SNDARGS[@]+"${SNDARGS[@]}"} \
	${START[@]+"${START[@]}"} >/dev/null 2>&1 &
ENGINE_PID=$!

# Start the encoder. It opens the FIFO (input 0) and blocks until the engine's
# startmovie connects as writer; the pulse input (1) opens right after, so audio
# and video start together. Frames are bottom-up -> -vf vflip. -video_size must
# equal the render size (we forced it above); the engine logs the actual size.
FFLOG="dist/ffmpeg-${DEMO}.log"
echo "recording -> $OUT ($ENCODER${MON:+ + audio}); ffmpeg log -> $FFLOG"
ffmpeg -hide_banner -loglevel verbose -y \
	-f rawvideo -pixel_format rgba -video_size "${WIDTH}x${HEIGHT}" -framerate "$FPS" \
	-thread_queue_size 1024 -i "$FIFO" \
	${AUDIO_IN[@]+"${AUDIO_IN[@]}"} \
	-vf vflip ${AUDIO_MAP[@]+"${AUDIO_MAP[@]}"} "${VOPTS[@]}" -pix_fmt yuv420p \
	-movflags +faststart "$OUT" 2>"$FFLOG" &
FFMPEG_PID=$!

# wait for playback to begin (covers preload + startmovie), then for it to end.
wait_for_marker "Demo playback started" 120 || { echo "demo never started" >&2; exit 1; }
echo "capturing..."

# wait for the demo to end — but also bail (and surface the log) if ffmpeg dies
# mid-capture, instead of hanging until the demo finishes or the window closes.
while ! grep -qF "Demo playback ended" "$LOG" 2>/dev/null; do
	kill -0 "$FFMPEG_PID" 2>/dev/null || { echo "ffmpeg exited during capture — see $FFLOG:" >&2; tail -8 "$FFLOG" >&2; break; }
	kill -0 "$ENGINE_PID" 2>/dev/null || { echo "engine exited during capture" >&2; break; }
	sleep 0.25
done

# the engine closed the FIFO (CL_StopMovie on demo end) -> video hits EOF. ffmpeg
# self-exits once audio is also done; if audio is still live it won't, so give it
# a short grace to drain the buffered frames, then SIGINT (finalizes cleanly).
for _ in $(seq 1 8); do kill -0 "$FFMPEG_PID" 2>/dev/null || break; sleep 0.25; done
kill -INT "$FFMPEG_PID" 2>/dev/null || true
wait "$FFMPEG_PID" 2>/dev/null || true
FFMPEG_PID=""

kill "$ENGINE_PID" 2>/dev/null || true
wait "$ENGINE_PID" 2>/dev/null || true
ENGINE_PID=""

cleanup              # restore the temp cfg + remove the FIFO now
trap - EXIT INT TERM
echo "done: $OUT ($(du -h "$OUT" | cut -f1))"
