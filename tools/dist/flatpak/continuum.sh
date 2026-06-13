#!/bin/sh
# Half-Life: Continuum Edition — in-sandbox launcher (installed at /app/bin/continuum).
#
# The flatpak ships only the engine, the game libraries and the Continuum
# menu assets — never game content. Those live read-only in /app and are
# mounted as the engine's RODIR. Everything the engine writes (configs,
# saves, downloaded content) and the player's own game files live in the
# writable BASEDIR under the app's data directory.
set -e

export LD_LIBRARY_PATH="/app/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# our read-only overlay: game .so libs + Continuum fonts/glyphs
export XASH3D_RODIR="/app/share/continuum"

# writable base: ~/.var/app/<appid>/data  (XDG_DATA_HOME inside the sandbox)
BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$BASE/valve"
export XASH3D_BASEDIR="$BASE"

# first-run hint if the player hasn't added any game content yet
if [ ! -e "$BASE/valve/liblist.gam" ] && [ ! -e "$BASE/valve/gameinfo.txt" ]; then
	echo "Continuum: no Half-Life game data found in $BASE/valve" >&2
	echo "Copy or symlink your 'valve' folder there (see the README)." >&2
fi

exec /app/bin/xash3d -log "$@"
