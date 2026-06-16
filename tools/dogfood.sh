#!/bin/bash
# Dogfood test cycle — build the linux-amd64 package exactly as a user receives
# it (engine + game libs built in the container, then redist/ copied on top),
# extract it into ./dist-test/, and run it.
#
# dist-test/ is NOT cleared first: a `valve` folder you drop there (your own
# Half-Life assets) survives across runs, and the package's libs/content merge on
# top — same "drop in valve and merge" flow the end user follows.
#
# Usage:
#   tools/dogfood.sh [engine args...]      # build, extract, run
#       e.g. tools/dogfood.sh -game gearbox
#   tools/dogfood.sh --no-run [args...]    # build + extract only
set -e
cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
ART="$ROOT/dist/artifacts/continuum-linux-amd64.tar.gz"

run=1
if [ "${1:-}" = "--no-run" ]; then run=0; shift; fi

echo "=== building linux-amd64 package ==="
tools/build_all.sh linux-amd64

echo "=== extracting -> dist-test/ (merge; not cleared) ==="
mkdir -p dist-test
# the artifact holds a top-level linux-amd64/ dir; strip it so the package
# contents (xash3d.sh, continuum/, uplink/, valve/…) land directly in dist-test/.
tar xzf "$ART" -C dist-test --strip-components=1
echo "dist-test/ ready:"; ls -1 dist-test

if [ "$run" = 1 ]; then
    echo "=== launching dist-test/xash3d.sh (Ctrl-C to quit) ==="
    exec dist-test/xash3d.sh "$@"
else
    echo "skip run (--no-run); launch with: ./dist-test/xash3d.sh"
fi
