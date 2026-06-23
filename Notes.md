# Notes

## Github Repositories

Umbrella project: https://github.com/bishopdynamics/Continuum
xash3d fork: https://github.com/bishopdynamics/xash3d-fwgs
mainui fork: https://github.com/bishopdynamics/mainui_cpp
hlsdk fork: https://github.com/bishopdynamics/hlsdk-portable


## Small Things

- AO for a dead body is weaker than the entity shadow, so when entity dies shadow changes strength
- capture-demo.sh: 
  - need to override to windowed mode when capturing
  - need to override console enabled, otherwise the mark verb cannot be seen by the script

## Feature Creep

- watch-me-play / HLTV
  - there was a feature of multiplayer half-life (mostly counter-strike) called HLTV, where uers could join a server as a pure-spectator, and they could jump around between all the players in the game and watch from their perspective (firstperson) or behind-cam (thirdperson)
  - I want to be able to invite another player (also running continuum edition) to spectate, with the option to trade-places (i let my friend take over, playing for a few maps while i spectate). This is essentially a two-client single-player game, where either player can be the "driver", but only one at a time, while the other spectates. 



## Map capture & ingest (chapter thumbnails + loadouts)

This is implemented, but user needs to play thru valve/gearbox/bshift to
capture all the thumbnails and loadout data.

Two-step dev workflow to generate chapter thumbnails and starting loadouts by
just playing the games. Implemented in the game DLLs (hlsdk client.cpp) + a
host ingest script.

1. Capture: launch a game, open the console (`~`), `sv_capture_maps 1`, then
   play through start -> finish. On *first arrival* to each map the DLL grabs a
   clean screenshot (HUD + viewmodel hidden) and dumps the carried weapons/items:
     - `dist-test/<game>/capture/<map>.png`
     - `dist-test/<game>/capture/<map>.txt`
   First-arrival only (re-entering / reloading a save won't clobber it). Do this
   for valve, gearbox (of), bshift.
2. Ingest: `tools/ingest-captures.py` (`--dry-run` to preview). Downscales the
   screenshots into `redist/continuum/gfx/shell/continuum/chapters/<game>_<map>.png`
   and fills each chapter's loadout column in `chapters_<game>.lst` from the
   capture of *that chapter's currently-listed map*. Re-runnable; only touches
   changed loadout tokens. Reassign a chapter's map and re-run to re-pull.

The captured loadout is just the weapon/item set. The chapter-start apply-hook
applies the rest of the policy uniformly: health 100, armor 100 (when suited),
ammo topped to 50% of max per weapon.

### Deferred: make preloaded worlds render-ready (maybe unnecessary)

Follow-up to the demo/savegame "missing tram faces" fix (2026-06-17). A world
warmed only by `world_preload` has never been through a connect-time render
build (R_NewMap/GL_BuildLightmaps), so restoring it from the residency cache
drops moving-brush (`*N`) faces. We sidestep this by forcing a fresh world load
on cold session entry (load-savegame + demo-start, via `Mod_ForceFreshWorld`),
keeping the residency fast path for in-game changelevels.

Potential cleaner fix: have `world_preload` build the GL render data up front so
preloaded worlds are genuinely render-ready, removing the need to force-fresh.
May not be worth it — the force-fresh costs only one extra parse on a load that
already shows a loading screen.

