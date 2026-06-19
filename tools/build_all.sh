#!/bin/bash
# Build distributable packages for every supported platform, each inside a
# reproducible Docker container. Build host: linux-amd64.
#
# Usage: tools/build_all.sh [target...]
#   targets: linux-amd64 linux-arm64 win32   (default: all three)
#   flatpak: x86_64 Steam Deck / Linux bundle (builds linux-amd64 first)
#   macos: not buildable from this host — see the note printed at the end.
#
# Output: dist/<target>/ staged trees and dist/artifacts/*.tar.gz|.zip
set -e

cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
DIST=$ROOT/dist
SDL_VERSION=2.32.10

TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(linux-amd64 linux-arm64 win32)

# Continuum's own always-mounted assets, committed under redist/continuum and
# ALWAYS bundled. The per-game menu backgrounds (gfx/shell/continuum/games) are
# composed at runtime from the user's own files and are intentionally absent from
# redist/continuum, so they never ship.
stage_assets()
{
    local out=$1
    mkdir -p "$out/continuum"
    cp -a redist/continuum/. "$out/continuum/"
    cp tools/dist/README-DIST.md "$out/README.md"

    # Continuum version stamp read by the menu (RootMenu): the 4-component VERSION
    # (committed source of truth at the repo root) plus the umbrella short commit,
    # so any screenshot of the root menu traces to an exact build. "-dirty" is
    # appended when building from an uncommitted (tracked) tree.
    local ver commit dirty=""
    ver=$(tr -d '[:space:]' < VERSION)
    commit=$(git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)
    git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null || dirty="-dirty"
    mkdir -p "$out/continuum/gfx/shell/continuum"
    printf '%s-%s%s\n' "$ver" "$commit" "$dirty" > "$out/continuum/gfx/shell/continuum/version.txt"
}

ensure_binfmt_arm64()
{
    if ! docker run --rm --platform linux/arm64 debian:bookworm-slim true 2>/dev/null; then
        echo "[build_all] registering qemu binfmt handlers (one-time, needs privileged docker)"
        docker run --privileged --rm tonistiigi/binfmt --install arm64
    fi
}

build_linux()
{
    local arch=$1 platform=linux/$2
    local out=$DIST/linux-$arch

    echo "==== linux-$arch ===="
    docker build --platform "$platform" --build-arg SDL_VERSION=$SDL_VERSION \
        -t continuum-build:linux-$arch -f tools/dist/Dockerfile.linux tools/dist
    rm -rf "$out" && mkdir -p "$out"
    docker run --rm --platform "$platform" \
        -v "$ROOT:/src:ro" -v "$out:/out" --user "$(id -u):$(id -g)" \
        continuum-build:linux-$arch sh /src/tools/dist/build-linux.sh

    stage_assets "$out"
    cp tools/dist/xash3d.sh "$out/xash3d.sh" && chmod +x "$out/xash3d.sh"

    mkdir -p "$DIST/artifacts"
    tar -C "$DIST" -czf "$DIST/artifacts/continuum-linux-$arch.tar.gz" "linux-$arch"
    echo "==== linux-$arch done -> dist/artifacts/continuum-linux-$arch.tar.gz"
}

build_win32()
{
    local out=$DIST/win32

    echo "==== win32 (i686) ===="
    docker build --build-arg SDL_VERSION=$SDL_VERSION \
        -t continuum-build:win32 -f tools/dist/Dockerfile.win32 tools/dist
    rm -rf "$out" && mkdir -p "$out"
    docker run --rm -v "$ROOT:/src:ro" -v "$out:/out" --user "$(id -u):$(id -g)" \
        continuum-build:win32 sh /src/tools/dist/build-win32.sh

    stage_assets "$out"

    mkdir -p "$DIST/artifacts"
    ( cd "$out" && zip -qr "$DIST/artifacts/continuum-win32.zip" . )
    echo "==== win32 done -> dist/artifacts/continuum-win32.zip"
}

for t in "${TARGETS[@]}"; do
    case "$t" in
        linux-amd64) build_linux amd64 amd64 ;;
        linux-arm64) ensure_binfmt_arm64; build_linux arm64 arm64 ;;
        win32) build_win32 ;;
        flatpak) build_linux amd64 amd64; bash "$ROOT/tools/dist/build-flatpak.sh" ;;
        macos)
            echo "macos: cannot be built from this host without an Apple SDK."
            echo "On a Mac: clone the repo and run scripts/gha/build_apple.sh"
            echo "(or open an osxcross toolchain question when we get there)."
            ;;
        *) echo "unknown target: $t (linux-amd64 linux-arm64 win32 flatpak)"; exit 1 ;;
    esac
done

echo
echo "All requested targets built. Artifacts in dist/artifacts/"
