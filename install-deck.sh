#!/bin/bash
# Build the Half-Life: Continuum Edition flatpak and install it on a Steam
# Deck (or any Linux box) over SSH.
#
# Usage:
#   DECK_SSH=deck@steamdeck.local ./install-deck.sh [--run]
#
# Environment:
#   DECK_SSH   ssh target as user@hostname  (required)
#              e.g. deck@steamdeck.local, or deck@192.168.1.42
#
# Options:
#   --run      launch the game on the Deck after installing
#
# The Deck must have SSH enabled (Desktop mode: System Settings, or
# `sudo systemctl enable --now sshd`) and be reachable from this machine.
set -euo pipefail

APPID=org.continuum.HalfLife
RUNTIME=org.freedesktop.Platform/x86_64/25.08

: "${DECK_SSH:?set DECK_SSH=user@hostname (e.g. DECK_SSH=deck@steamdeck.local)}"

cd "$(dirname "$0")"
ART=dist/artifacts/continuum.flatpak

echo "==> building the flatpak bundle"
tools/dist/build-flatpak.sh

echo "==> checking SSH to $DECK_SSH"
ssh -o ConnectTimeout=10 "$DECK_SSH" true

echo "==> copying bundle to $DECK_SSH ($(du -h "$ART" | cut -f1))"
ssh "$DECK_SSH" 'mkdir -p ~/continuum-install'
scp "$ART" "$DECK_SSH:continuum-install/continuum.flatpak"

echo "==> installing on the Deck (this pulls the runtime from flathub if needed)"
ssh "$DECK_SSH" bash -s <<EOF
set -e
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y --noninteractive flathub $RUNTIME || true
flatpak install --user -y --noninteractive --reinstall ~/continuum-install/continuum.flatpak
echo "--- installed ---"
flatpak info $APPID | grep -iE 'ID:|Version:|Installed:' || true
EOF

cat <<EOF

Installed $APPID on $DECK_SSH.

Add your game data (on the Deck). The fast way, if Half-Life is on the
internal drive, is a symlink (no copy):

  ssh $DECK_SSH 'ln -sfn ~/.local/share/Steam/steamapps/common/Half-Life/valve \\
    ~/.var/app/$APPID/data/valve'

Or copy it (works from any drive, but duplicates ~1 GB):

  ssh $DECK_SSH 'cp -r ~/.local/share/Steam/steamapps/common/Half-Life/valve \\
    ~/.var/app/$APPID/data/'

Expansions (Opposing Force etc.) go next to valve the same way:
  ~/.var/app/$APPID/data/gearbox , .../bshift , ...

Launch:  ssh $DECK_SSH 'flatpak run $APPID'
   or:   from the Deck app grid, or add it to Steam as a non-Steam game.
   expansion:  flatpak run $APPID -game gearbox
EOF

if [ "${1:-}" = "--run" ]; then
	echo "==> launching on the Deck"
	ssh "$DECK_SSH" "flatpak run $APPID" || true
fi
