#!/bin/bash
# Build the macOS Continuum.app (arm64) — a native, NON-Docker build.
#
# Unlike the linux/win32 dist targets this needs Apple's SDK + the SDL2
# framework, which only exist on macOS, so it must run natively on a Mac. On any
# other host it prints guidance and exits non-zero.
#
# Bundle model (same as the flatpak's read-only install — see searchpath.c):
#   Continuum.app/Contents/
#     MacOS/Continuum            launcher (CFBundleExecutable; sets RODIR/BASEDIR)
#     MacOS/xash3d + *.dylib     engine + support libs
#     Frameworks/SDL2.framework  bundled SDL2 (reached via an @rpath entry)
#     Resources/continuum/       always-mounted Continuum assets (the RODIR)
#     Resources/<game>/dlls,...  per-mod game libraries we build (also RODIR)
# The player's game content + all writes live in a writable data dir:
#   ~/Library/Application Support/Continuum   (the BASEDIR the launcher sets)
#
# Output: dist/macos/Continuum.app and dist/artifacts/continuum-macos-arm64.zip
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
	cat <<'EOF'
macos: cannot be built from this host — Apple's SDK only runs on macOS.

On a Mac:
  1. install the official SDL2 framework (real SDL2, NOT brew's sdl2-compat):
       curl -LO https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.dmg
       hdiutil attach SDL2-2.32.10.dmg
       cp -R /Volumes/SDL2/SDL2.framework ~/Library/Frameworks/
  2. git clone --recursive this repo
  3. make macos
EOF
	exit 1
fi

cd "$(dirname "$0")/../.." || exit 1
ROOT=$PWD
ARCH=arm64                       # arm64-only for now (universal is a later pass)
DIST=$ROOT/dist
STAGE=$DIST/macos
APP=$STAGE/Continuum.app
MACOS=$APP/Contents/MacOS
FRW=$APP/Contents/Frameworks
RES=$APP/Contents/Resources
MACDIST=$ROOT/tools/dist/macos

# --- locate the SDL2 framework (prefer the per-user path; no sudo needed) -----
SDL2_FW=""
for fw in "$HOME/Library/Frameworks/SDL2.framework" /Library/Frameworks/SDL2.framework; do
	[ -d "$fw" ] && { SDL2_FW=$fw; break; }
done
[ -n "$SDL2_FW" ] || { echo "SDL2.framework not found in ~/Library/Frameworks or /Library/Frameworks (see header)"; exit 1; }

NPROC=$(sysctl -n hw.ncpu)
echo "==== Continuum.app ($ARCH) ===="
rm -rf "$STAGE"
mkdir -p "$MACOS" "$FRW" "$RES"

# --- engine (native waf build into a throwaway copy, kept out of the dev tree)-
echo "=== engine ==="
ENGINE=$(mktemp -d)/engine
mkdir -p "$ENGINE"
( cd "$ROOT/xash3d-fwgs" && tar cf - --exclude=./build . ) | tar xf - -C "$ENGINE"
ENGINE_INSTALL=$(mktemp -d)
(
	cd "$ENGINE"
	./waf configure -T release --enable-stbtt --sdl2="$SDL2_FW"
	./waf build -j"$NPROC"
	./waf install --destdir="$ENGINE_INSTALL"
)
# engine binaries (launcher + libs) -> Contents/MacOS; the install also lays
# down valve/extras.pk3 -> that belongs in the read-only overlay (Resources).
cp "$ENGINE_INSTALL"/xash3d "$ENGINE_INSTALL"/*.dylib "$MACOS/"
[ -d "$ENGINE_INSTALL/valve" ] && cp -a "$ENGINE_INSTALL/valve" "$RES/"

# --- game libraries (per-mod, from hlsdk-portable branches) -> Resources ------
echo "=== game libraries ==="
CONFIGURE_FLAGS="-T release" OUT="$RES" \
	python3 "$ROOT/tools/dist/build-game-libs.py"

# --- Continuum assets (always-mounted) -> Resources/continuum -----------------
# Mirrors stage_assets() in tools/build_all.sh: copy redist/continuum and stamp
# the menu version (4-component VERSION + umbrella short commit, "-dirty" when
# building from an uncommitted tracked tree).
echo "=== continuum assets ==="
mkdir -p "$RES/continuum"
cp -a "$ROOT/redist/continuum/." "$RES/continuum/"
VER=$(tr -d '[:space:]' < "$ROOT/VERSION")
COMMIT=$(git -C "$ROOT" rev-parse --short=8 HEAD 2>/dev/null || echo unknown)
DIRTY=""
git -C "$ROOT" diff --quiet 2>/dev/null && git -C "$ROOT" diff --cached --quiet 2>/dev/null || DIRTY="-dirty"
mkdir -p "$RES/continuum/gfx/shell/continuum"
printf '%s-%s%s\n' "$VER" "$COMMIT" "$DIRTY" > "$RES/continuum/gfx/shell/continuum/version.txt"

# --- SDL2 framework + rpath ---------------------------------------------------
# libxash links @rpath/SDL2.framework; add an rpath to Contents/Frameworks so it
# resolves from there (xash3d's rpaths are searched for the dylibs it loads).
echo "=== bundle SDL2 ==="
cp -R "$SDL2_FW" "$FRW/"
install_name_tool -add_rpath "@loader_path/../Frameworks" "$MACOS/xash3d" 2>/dev/null || true

# --- launcher + Info.plist + icon ---------------------------------------------
echo "=== bundle metadata ==="
install -m755 "$MACDIST/launcher.sh" "$MACOS/Continuum"
sed "s/@VERSION@/$VER/g" "$MACDIST/Info.plist.in" > "$APP/Contents/Info.plist"

# icon: build Continuum.icns from the lambda mark (best-effort)
ICON_SRC=$ROOT/redist/continuum/gfx/shell/continuum/lambda.png
if [ -f "$ICON_SRC" ] && command -v iconutil >/dev/null && command -v sips >/dev/null; then
	ICONSET=$(mktemp -d)/Continuum.iconset
	mkdir -p "$ICONSET"
	for s in 16 32 64 128 256 512 1024; do
		sips -z "$s" "$s" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null 2>&1 || true
	done
	# retina (@2x) variants Apple expects
	cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"   2>/dev/null || true
	cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"   2>/dev/null || true
	cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png" 2>/dev/null || true
	cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png" 2>/dev/null || true
	cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true
	rm -f "$ICONSET/icon_1024x1024.png"
	iconutil -c icns "$ICONSET" -o "$RES/Continuum.icns" 2>/dev/null || true
fi

# --- codesign -----------------------------------------------------------------
# With CONTINUUM_SIGN_ID set to a "Developer ID Application: NAME (TEAMID)"
# identity, sign inside-out with the hardened runtime + a secure timestamp, so
# the bundle can be notarized. Without it, fall back to an ad-hoc signature —
# fine for local runs, but a *downloaded* ad-hoc app is Gatekeeper-quarantined.
SIGN_ID=${CONTINUUM_SIGN_ID:-}
ENTITLEMENTS=$MACDIST/entitlements.plist
if [ -n "$SIGN_ID" ]; then
	echo "=== codesign (Developer ID: $SIGN_ID) ==="
	sign() { codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$@"; }
	# 1) nested code first: engine + per-mod game-lib dylibs, then the framework
	while IFS= read -r -d '' f; do sign "$f"; done \
		< <(find "$MACOS" "$RES" -name '*.dylib' -print0)
	sign "$FRW/SDL2.framework"
	# 2) the executable the launcher exec's (carries the entitlements)
	sign --entitlements "$ENTITLEMENTS" "$MACOS/xash3d"
	# 3) the bundle itself, last
	sign --entitlements "$ENTITLEMENTS" "$APP"
	codesign --verify --deep --strict "$APP" && echo "  signature OK"
else
	echo "=== codesign (ad-hoc — set CONTINUUM_SIGN_ID to enable notarization) ==="
	codesign --force --deep --sign - "$APP" 2>/dev/null || \
		echo "  (ad-hoc codesign failed — app still runs locally if you clear quarantine)"
fi

# --- package ------------------------------------------------------------------
mkdir -p "$DIST/artifacts"
OUT=$DIST/artifacts/continuum-macos-$ARCH.zip
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT"

# --- notarize + staple --------------------------------------------------------
# Needs a real Developer ID signature AND a stored notarytool keychain profile
# (CONTINUUM_NOTARY_PROFILE — create once with `xcrun notarytool
# store-credentials`). Submits the zip, waits for Apple, staples the ticket onto
# the .app, then re-zips so the artifact carries the ticket (passes Gatekeeper
# offline on first launch).
NOTARY_PROFILE=${CONTINUUM_NOTARY_PROFILE:-}
if [ -n "$SIGN_ID" ] && [ -n "$NOTARY_PROFILE" ]; then
	echo "=== notarize (profile: $NOTARY_PROFILE) ==="
	xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait
	echo "=== staple ==="
	xcrun stapler staple "$APP"
	xcrun stapler validate "$APP" && echo "  staple OK"
	rm -f "$OUT"
	ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT"   # re-zip the stapled app
elif [ -n "$NOTARY_PROFILE" ]; then
	echo "=== notarize SKIPPED — needs a Developer ID signature (set CONTINUUM_SIGN_ID) ==="
fi

echo
echo "==== done ===="
echo "  app:      $APP"
echo "  artifact: $OUT ($(du -h "$OUT" | cut -f1))"
echo "  signing:  ${SIGN_ID:-ad-hoc (local only)}"
echo "  notarized: $([ -n "$SIGN_ID" ] && [ -n "$NOTARY_PROFILE" ] && echo yes || echo no)"
echo "  player game data goes in: ~/Library/Application Support/Continuum/valve"
