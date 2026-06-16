#!/bin/bash
# clear baked world-AO caches (cache/ao/*.ao) so the next launch re-bakes them.
# Handy for testing the first-launch bake / progress bar repeatedly.
#
# Usage:
#   tools/clear-ao-cache.sh            # clear caches under dist-test/*/
#   tools/clear-ao-cache.sh <dir>...   # clear caches under the given game dir(s)
cd "$(dirname "$0")/.." || exit 1   # repo root

shopt -s nullglob

# default search roots: every game dir in dist-test/
roots=( "$@" )
if [ ${#roots[@]} -eq 0 ]; then
	roots=( dist-test/* )
fi

total=0
for r in "${roots[@]}"; do
	d="$r/cache/ao"
	[ -d "$d" ] || continue
	files=( "$d"/*.ao )
	[ ${#files[@]} -eq 0 ] && continue
	rm "${files[@]}"
	echo "cleared ${#files[@]} cache(s) from $d"
	total=$(( total + ${#files[@]} ))
done

if [ "$total" -eq 0 ]; then
	echo "no AO caches found"
else
	echo "cleared $total AO cache file(s) total"
fi
