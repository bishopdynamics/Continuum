#!/bin/bash
# Capture every recorded demo in demos/ to dist/<demo>.mp4 via
# capture-demo-video.sh, skipping any whose output already exists and is valid.
#
# The capture pipeline has a rare failure that ends the recording after a second
# or two, leaving a tiny (often single-frame) file. Every real demo is >= 10s and
# real footage runs about 1 MB/s, so a good capture is ~10 MB+ while a failed one
# is a fraction of a MB - we validate by file size and re-capture up to RETRIES
# times. (Duration is NOT a reliable signal: the broken file carries garbage
# container metadata, e.g. a bogus multi-thousand-hour duration.)
#
# Env overrides (GAME, WIDTH, FPS, ENCODER, ...) pass through to each capture.

cd "$(dirname "$0")/.." || exit 1   # repo root

MIN_MB=${MIN_MB:-5}    # a valid capture is at least this many MB (real >=10s runs
                       # are ~10 MB+; failed runs are under ~1 MB, so 5 MB cleanly
                       # separates them with margin)
RETRIES=${RETRIES:-2}  # extra attempts after the first (up to 1+RETRIES)

valid_capture() {
	local f=$1 bytes
	[ -f "$f" ] || return 1
	bytes=$(wc -c < "$f" 2>/dev/null || echo 0)
	[ "$bytes" -ge $(( MIN_MB * 1048576 )) ]
}

shopt -s nullglob
demos=(demos/*.dem)
if [ ${#demos[@]} -eq 0 ]; then
	echo "no demos found in demos/" >&2
	exit 1
fi

failed=()
for dem in "${demos[@]}"; do
	name=$(basename "$dem" .dem)
	out="dist/$name.mp4"

	if valid_capture "$out"; then
		echo "skip $name (already captured -> $out)"
		continue
	fi

	ok=0
	for attempt in $(seq 1 $(( RETRIES + 1 ))); do
		echo "=== capturing $name -> $out (attempt $attempt/$(( RETRIES + 1 ))) ==="
		./tools/capture-demo-video.sh "$name" || true

		if valid_capture "$out"; then
			ok=1
			break
		fi
		echo "capture of $name looks failed (< ${MIN_MB} MB); retrying" >&2
	done

	if [ "$ok" -ne 1 ]; then
		echo "FAILED: $name after $(( RETRIES + 1 )) attempts" >&2
		rm "$out" 2>/dev/null   # don't leave a bogus file a later run would skip
		failed+=("$name")
	fi
done

if [ ${#failed[@]} -gt 0 ]; then
	echo "done, but ${#failed[@]} failed: ${failed[*]}" >&2
	exit 1
fi
echo "done - all demos captured."
