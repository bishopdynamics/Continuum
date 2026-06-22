# Notes

## Small Things

- AO for a dead body is weaker than the entity shadow, so when entity dies shadow changes strength


## Remaining roadmap to v1 release

- complete the items in sections above this section (if any)
- before any public release: 
  - tighten the flatpak grant (currently --filesystem=home + --device=all)
  - documentation (see section below)


## Github Repositories

Umbrella project: https://github.com/bishopdynamics/Continuum
xash3d fork: https://github.com/bishopdynamics/xash3d-fwgs
mainui fork: https://github.com/bishopdynamics/mainui_cpp
hlsdk fork: https://github.com/bishopdynamics/hlsdk-portable


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


### Non-linux platform support

- windows: i dont have a machine to test, and I dont care
- macos (2026-06-21): native dev build WORKS on Apple Silicon (arm64). The old
  "32/64-bit" worry was moot — we build every game lib from hlsdk source, so an
  arm64 Mac just builds arm64 engine + arm64 game-lib dylibs. Toolchain: real
  SDL2 2.32.10 framework in ~/Library/Frameworks (NOT brew's sdl2 = sdl2-compat
  over SDL3). `tools/build-engine.sh` + `tools/dist/build-game-libs.py` now
  branch on OS; `make play` builds engine + all 4 game libs (valve/gearbox/
  bshift/hunger) and the engine launches (apple-arm64).
- macos dist bundle (2026-06-22): `make macos` builds Continuum.app (arm64),
  ad-hoc signed, ~30 MB zip in dist/artifacts/. Same read-only-install model as
  the flatpak: shipped assets + game libs are the engine's RODIR (Contents/
  Resources), the player's game folders + saves live in the writable BASEDIR
  ~/Library/Application Support/Continuum (launcher sets XASH3D_RODIR/BASEDIR;
  first run opens that folder + a dialog). Verified launching with content.
- macos notarization (2026-06-22): DONE. build-macos.sh signs (Developer ID +
  hardened runtime) + notarizes + staples when CONTINUUM_SIGN_ID +
  CONTINUUM_NOTARY_PROFILE are set (see tools/dist/macos/README-SIGNING.md).
  Produced a notarized arm64 bundle: spctl -> "accepted, Notarized Developer
  ID", staple valid, passes Gatekeeper from a quarantined download. Signing
  identity "Developer ID Application: James Bishop (8FWB63VG2N)", notary via
  App Store Connect API key stored as notarytool profile "continuum-notary".
  STILL TODO: universal arm64+x86_64 via lipo (currently arm64-only).

