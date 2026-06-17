#!/bin/bash
# Capture a recorded demo to an MP4: play the demo back on the engine and dump
# every rendered frame straight from the engine to an H.264 file in one pass.
# Replaces the old trio: capture-demo-video.sh, capture-all-demo-videos.sh,
# capture-gif-of-gameplay.sh.
#
# GAMEPLAY ONLY, MP4 ONLY. Demos can't record the menu UI (mainui isn't part of
# the demo stream); the menu-tour GIF is a separate hand-driven, screen-grabbed
# tools/capture-menu-gif.sh. GIFs of gameplay proved impractical (huge files for
# minutes-long demos), so this script no longer produces them — pull a short clip
# from the MP4 by hand if you ever need a loop.
#
# Frame source: the engine's `startmovie <fifo>` writes the raw RGBA backbuffer
# of every rendered frame to a FIFO (glReadPixels — no compositor, no async
# screen read, so no tearing). ffmpeg reads that FIFO as rawvideo and encodes
# H.264 (hardware when available — see ENCODER), capturing game audio from
# PulseAudio in parallel; the demo ending auto-stops the movie (engine closes the
# FIFO -> ffmpeg sees EOF). Frames are bottom-up (glReadPixels order); vflip flips.
#
# Output (dist/ is gitignored — copyrighted gameplay, NOT committed):
#   dist/media/<demo>.mp4   master capture
#
# Idempotent: a demo whose MP4 already passes the size check is skipped. FORCE=1
# re-captures regardless. The capture has a rare failure that ends after a second
# or two, leaving a tiny file — we validate by size and retry up to RETRIES times.
#
# Usage:
#   tools/capture-demo.sh [demo]
#     demo   demo name under demos/<demo>.dem. With NO arg, every demos/*.dem is
#            captured in turn (skipping ones already done).
#
# Env overrides:
#   GAME=valve  WIDTH=1280  HEIGHT=720  FPS=60   (capture; WIDTH/HEIGHT persist
#               into unified_video.cfg, so the game stays at this res. FPS must
#               match the render rate so the timeline is right.)
#   FPS_CAP=60  VSYNC=1                          (engine render pacing)
#   ENCODER=auto                                 (default: probe libcuda->nvenc,
#               else a render node->vaapi, else libx264. Survives GPU swaps.)
#   ENCODER=h264_nvenc  CQ=19  NVENC_PRESET=p6   (NVIDIA GPU encode; needs CUDA)
#   ENCODER=h264_vaapi  CQ=19  VAAPI_DEV=/dev/dri/renderD128  (AMD/Intel GPU)
#   ENCODER=libx264     CRF=18  PRESET=slow      (CPU; always works, no driver)
#   AUDIO=1  AUDIO_DEV=<src>  ABITRATE=192k      (game audio; AUDIO=0 off)
#   MIN_MB=5  RETRIES=2  FORCE=0  OUTDIR=dist/media
#
# Requires: ffmpeg (rawvideo + the chosen encoder), the movie-capable engine
# (startmovie/endmovie), pactl for audio.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1   # repo root

GAME=${GAME:-valve}
WIDTH=${WIDTH:-1280}
HEIGHT=${HEIGHT:-720}
FPS=${FPS:-60}
FPS_CAP=${FPS_CAP:-60}
VSYNC=${VSYNC:-1}
ENCODER=${ENCODER:-auto}         # auto-detect; or h264_nvenc/h264_vaapi/libx264
CQ=${CQ:-19}                     # NVENC/VAAPI constant quality (lower = better)
NVENC_PRESET=${NVENC_PRESET:-p6} # p1 fastest .. p7 best
CRF=${CRF:-18}                   # libx264 fallback quality
PRESET=${PRESET:-slow}           # libx264 fallback preset
VAAPI_DEV=${VAAPI_DEV:-/dev/dri/renderD128}  # AMD/Intel VAAPI render node
AUDIO=${AUDIO:-1}                # capture game audio too (PulseAudio/PipeWire)
AUDIO_DEV=${AUDIO_DEV:-}         # override the capture source (default: auto)
ABITRATE=${ABITRATE:-192k}
MIN_MB=${MIN_MB:-5}              # a valid capture is at least this many MB (real
                                 # >=10s runs are ~10 MB+, failed ones under ~1 MB)
RETRIES=${RETRIES:-2}            # extra attempts after the first (up to 1+RETRIES)
FORCE=${FORCE:-0}
OUTDIR=${OUTDIR:-dist/media}
LOG=dist-test/engine.log

# --- preflight -------------------------------------------------------------
command -v ffmpeg >/dev/null || { echo "missing required tool: ffmpeg" >&2; exit 1; }
[ -x dist-test/xash3d ] || { echo "engine not built — run tools/build-engine.sh first" >&2; exit 1; }
mkdir -p "$OUTDIR"

# --- encoder selection (computed once; demo-independent) -------------------
# A 1s lavfi->null encode is the cheapest honest "can this encoder actually
# init on this machine?" test — nvenc needs CUDA (libcuda.so.1, NVIDIA-only),
# vaapi needs a working render node; libx264 always works. Probing here means a
# GPU swap (e.g. NVIDIA->AMD) never silently breaks the capture: we pick what's
# present instead of dumping every frame into an encoder that can't open.
enc_can_init() {  # <encoder> [extra ffmpeg args before -c:v ...]
	local enc=$1; shift
	ffmpeg -hide_banner -loglevel error -f lavfi \
		-i testsrc=size=320x240:rate=10:duration=1 "$@" \
		-c:v "$enc" -f null - >/dev/null 2>&1
}

if [ "$ENCODER" = auto ]; then
	if enc_can_init h264_nvenc; then ENCODER=h264_nvenc
	elif [ -e "$VAAPI_DEV" ] && enc_can_init h264_vaapi \
		-vaapi_device "$VAAPI_DEV" -vf 'format=nv12,hwupload'; then ENCODER=h264_vaapi
	else ENCODER=libx264; fi
	echo "encoder: auto-selected $ENCODER"
else
	echo "encoder: $ENCODER (explicit)"
fi

# Per-encoder ffmpeg wiring. Frames arrive bottom-up RGBA, so every path vflips.
# VAAPI additionally uploads to a GPU surface (format=nv12,hwupload) and takes a
# device arg; its output is already an nv12 hwframe, so it must NOT get the
# software -pix_fmt yuv420p the other two need.
DEVOPTS=(); PIXFMT=(-pix_fmt yuv420p); VF=vflip
case "$ENCODER" in
*nvenc*)
	VOPTS=(-c:v "$ENCODER" -preset "$NVENC_PRESET" -rc vbr -cq "$CQ" -b:v 0) ;;
*vaapi*)
	DEVOPTS=(-vaapi_device "$VAAPI_DEV"); VF='vflip,format=nv12,hwupload'; PIXFMT=()
	VOPTS=(-c:v "$ENCODER" -rc_mode CQP -qp "$CQ") ;;
*)
	VOPTS=(-c:v "$ENCODER" -crf "$CRF" -preset "$PRESET") ;;
esac

# Fail-fast preflight: prove the resolved encoder + its exact filter/device wiring
# can init, so a broken encoder errors out clearly here instead of burning every
# capture attempt (the retry loop is for transient frame drops, not dead encoders).
if ! ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=size=320x240:rate=10:duration=1 \
	${DEVOPTS[@]+"${DEVOPTS[@]}"} -vf "$VF" "${VOPTS[@]}" ${PIXFMT[@]+"${PIXFMT[@]}"} \
	-f null - >/dev/null 2>&1; then
	echo "error: encoder '$ENCODER' failed to initialize on this system." >&2
	echo "  set ENCODER=libx264 (CPU, always works) or ENCODER=h264_vaapi (AMD/Intel)." >&2
	exit 1
fi

# audio: capture the monitor of the default output sink (= what the game plays).
AUDIO_IN=(); AUDIO_MAP=(); SNDARGS=(); MON=""
if [ "$AUDIO" = 1 ]; then
	MON="$AUDIO_DEV"
	if [ -z "$MON" ] && command -v pactl >/dev/null; then
		sink=$(pactl get-default-sink 2>/dev/null || true)
		[ -n "$sink" ] && MON="${sink}.monitor"
	fi
	if [ -n "$MON" ]; then
		AUDIO_IN=(-f pulse -thread_queue_size 1024 -i "$MON")
		# NO -shortest: if the pulse monitor EOFs early, -shortest would truncate
		# the whole video to that. Without it, video encodes to the end.
		AUDIO_MAP=(-map 0:v -map 1:a -c:a aac -b:a "$ABITRATE")
		# the engine mutes audio when the window loses focus (snd_mute_losefocus,
		# default 1); an automated capture never holds focus, so disable it.
		SNDARGS=(+snd_mute_losefocus 0)
	else
		echo "warning: no audio source (need pactl or AUDIO_DEV=); capturing video only" >&2
	fi
fi

# per-demo state cleaned up by per_demo_cleanup (also the EXIT/INT/TERM trap).
ENGINE_PID=""; FFMPEG_PID=""; FIFO=""; DONECFG=""; DONECFG_BAK=""

per_demo_cleanup() {
	[ -n "$FFMPEG_PID" ] && kill -INT "$FFMPEG_PID" 2>/dev/null && wait "$FFMPEG_PID" 2>/dev/null || true
	[ -n "$ENGINE_PID" ] && kill "$ENGINE_PID" 2>/dev/null || true
	if [ -n "$DONECFG_BAK" ]; then mv "$DONECFG_BAK" "$DONECFG"
	elif [ -n "$DONECFG" ] && [ -f "$DONECFG" ]; then rm "$DONECFG"; fi
	[ -n "$FIFO" ] && [ -p "$FIFO" ] && rm "$FIFO"
	ENGINE_PID=""; FFMPEG_PID=""; FIFO=""; DONECFG=""; DONECFG_BAK=""
}
trap per_demo_cleanup EXIT INT TERM

valid_mp4() {  # <file> — true if it exists and is at least MIN_MB
	local f=$1 bytes
	[ -f "$f" ] || return 1
	bytes=$(wc -c < "$f" 2>/dev/null || echo 0)
	[ "$bytes" -ge $(( MIN_MB * 1048576 )) ]
}

# wait for a log marker (the log is freshly truncated on each launch)
wait_for_marker() {
	local marker=$1 timeout=$2 waited=0
	while ! grep -qF "$marker" "$LOG" 2>/dev/null; do
		sleep 0.25; waited=$((waited + 1))
		[ "$waited" -ge $((timeout * 4)) ] && return 1
		kill -0 "$ENGINE_PID" 2>/dev/null || { echo "  engine exited early" >&2; return 1; }
	done
}

# force the capture resolution. The window is born from the width/height
# RENDERINFO cvars; unified_video.cfg re-applies them after the -width/-height
# cmdline, so set them there directly (persists; the game stays at this res).
force_resolution() {
	local vidcfg="dist-test/$GAME/unified_video.cfg" kv c v
	[ -f "$vidcfg" ] || vidcfg="dist-test/valve/unified_video.cfg"
	if [ -f "$vidcfg" ]; then
		for kv in "width=$WIDTH" "height=$HEIGHT"; do
			c=${kv%=*}; v=${kv#*=}
			if grep -qE "^$c \"" "$vidcfg"; then
				sed -i "s/^$c \"[^\"]*\"/$c \"$v\"/" "$vidcfg"
			else
				printf '%s "%s"\n' "$c" "$v" >> "$vidcfg"
			fi
		done
	else
		echo "  warning: no unified_video.cfg; render size may not match ${WIDTH}x${HEIGHT}" >&2
	fi
}

# capture_mp4 <demo> <out.mp4> — play the demo and grab frames to the MP4.
# Always invoked in an `|| true` context, so errexit is OFF inside; failure
# points return 1 explicitly. The caller validates the output by size.
capture_mp4() {
	local demo=$1 out=$2 fflog

	# stage the demo into the gamedir so playdemo finds it
	cp "demos/$demo.dem" "dist-test/$GAME/$demo.dem"

	FIFO=$(mktemp -u --suffix=.rawvideo); mkfifo "$FIFO"

	# Let the campaign streaming preload finish at the menu, THEN start playback
	# (first map resident, seamless transitions). A commandline +cmd is prepended
	# ahead of the queued world_preloads, so instead we drop a temp
	# streampreload_done.cfg the engine execs once the preload queue drains (a hook
	# in Host_QueueStreamPreload). It runs `startmovie <fifo>` then `playdemo`.
	# (This hook is the only path that reaches startmovie.)
	DONECFG="dist-test/$GAME/streampreload_done.cfg"; DONECFG_BAK=""
	[ -f "$DONECFG" ] && { DONECFG_BAK="$DONECFG.capbak"; cp "$DONECFG" "$DONECFG_BAK"; }
	# con_notifytime 0 suppresses the console notify overlay so captures are clean.
	# The engine runs with -nowriteconfig, so this never persists to config.cfg.
	printf '// temporary — tools/capture-demo.sh, removed after.\ncon_notifytime 0\nstartmovie "%s"\nplaydemo %s\n' \
		"$FIFO" "$demo" > "$DONECFG"

	force_resolution

	echo "  launching $GAME, warming campaign, capturing $demo at ${WIDTH}x${HEIGHT}..."
	# -nowriteconfig: throwaway session; don't persist its transient cvars
	# (con_notifytime, fps_max, gl_vsync, snd_mute_losefocus). The capture
	# resolution still persists separately via force_resolution above.
	./play-continuum.sh "$GAME" -windowed -nowriteconfig -width "$WIDTH" -height "$HEIGHT" \
		+fps_max "$FPS_CAP" +gl_vsync "$VSYNC" ${SNDARGS[@]+"${SNDARGS[@]}"} >/dev/null 2>&1 &
	ENGINE_PID=$!

	# Start the encoder. It opens the FIFO (input 0) and blocks until the engine's
	# startmovie connects as writer; the pulse input (1) opens right after. Frames
	# are bottom-up -> -vf vflip. -video_size must equal the render size.
	fflog=$(mktemp --suffix=.ffmpeg.log)
	echo "  recording -> $out ($ENCODER${MON:+ + audio})"
	ffmpeg -hide_banner -loglevel verbose -y \
		${DEVOPTS[@]+"${DEVOPTS[@]}"} \
		-f rawvideo -pixel_format rgba -video_size "${WIDTH}x${HEIGHT}" -framerate "$FPS" \
		-thread_queue_size 1024 -i "$FIFO" \
		${AUDIO_IN[@]+"${AUDIO_IN[@]}"} \
		-vf "$VF" ${AUDIO_MAP[@]+"${AUDIO_MAP[@]}"} "${VOPTS[@]}" ${PIXFMT[@]+"${PIXFMT[@]}"} \
		-movflags +faststart "$out" 2>"$fflog" &
	FFMPEG_PID=$!

	if ! wait_for_marker "Demo playback started" 120; then
		echo "  demo never started" >&2
		tail -8 "$fflog" 2>/dev/null >&2 || true
		per_demo_cleanup; [ -f "$fflog" ] && rm "$fflog"; return 1
	fi
	echo "  capturing..."

	# wait for the demo to end — but bail (and surface the log) if ffmpeg dies
	# mid-capture instead of hanging until the window closes.
	while ! grep -qF "Demo playback ended" "$LOG" 2>/dev/null; do
		kill -0 "$FFMPEG_PID" 2>/dev/null || { echo "  ffmpeg exited during capture:" >&2; tail -8 "$fflog" 2>/dev/null >&2; break; }
		kill -0 "$ENGINE_PID" 2>/dev/null || { echo "  engine exited during capture" >&2; break; }
		sleep 0.25
	done

	# the engine closed the FIFO (CL_StopMovie on demo end) -> video hits EOF.
	# ffmpeg self-exits once audio is also done; give it a short grace to drain
	# buffered frames, then SIGINT (finalizes cleanly).
	for _ in $(seq 1 8); do kill -0 "$FFMPEG_PID" 2>/dev/null || break; sleep 0.25; done
	kill -INT "$FFMPEG_PID" 2>/dev/null || true
	wait "$FFMPEG_PID" 2>/dev/null || true
	FFMPEG_PID=""
	kill "$ENGINE_PID" 2>/dev/null || true
	wait "$ENGINE_PID" 2>/dev/null || true
	ENGINE_PID=""

	per_demo_cleanup
	[ -f "$fflog" ] && rm "$fflog"
	return 0
}

# capture_one <demo> — full pipeline for one demo with skip/retry. Returns
# non-zero only on a capture that fails after all retries.
capture_one() {
	local demo=$1
	local mp4="$OUTDIR/$demo.mp4" ok=0 attempt

	if [ "$FORCE" != 1 ] && valid_mp4 "$mp4"; then
		echo "skip $demo (mp4 already in $OUTDIR)"
		return 0
	fi

	for attempt in $(seq 1 $(( RETRIES + 1 ))); do
		echo "=== capturing $demo -> $mp4 (attempt $attempt/$(( RETRIES + 1 ))) ==="
		[ -f "$mp4" ] && rm "$mp4"
		capture_mp4 "$demo" "$mp4" || true
		if valid_mp4 "$mp4"; then ok=1; break; fi
		echo "  capture looks failed (< ${MIN_MB} MB); retrying" >&2
	done

	if [ "$ok" != 1 ]; then
		echo "FAILED: $demo after $(( RETRIES + 1 )) attempts" >&2
		[ -f "$mp4" ] && rm "$mp4"   # don't leave a bogus file a later run would skip
		return 1
	fi

	echo "done: $mp4 ($(du -h "$mp4" | cut -f1))"
}

# --- main ------------------------------------------------------------------
if [ -n "${1:-}" ]; then
	[ -f "demos/$1.dem" ] || { echo "no demo at demos/$1.dem" >&2; exit 1; }
	capture_one "$1"
else
	shopt -s nullglob
	demos=(demos/*.dem)
	[ ${#demos[@]} -gt 0 ] || { echo "no demos found in demos/" >&2; exit 1; }
	failed=()
	for dem in "${demos[@]}"; do
		capture_one "$(basename "$dem" .dem)" || failed+=("$(basename "$dem" .dem)")
	done
	if [ ${#failed[@]} -gt 0 ]; then
		echo "done, but ${#failed[@]} failed: ${failed[*]}" >&2
		exit 1
	fi
	echo "done — all demos captured."
fi
