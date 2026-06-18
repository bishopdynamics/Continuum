# Notes


## Menu Tour Scripting System

Enhancements to our already-awesome menu tour scripting system

- can we handle switching games?
  - if my script navigates to blue shift, and then the game restarts, i assume our script is gone. can we resume execution?

## Remaining roadmap to v1 release

- complete the items in sections above this section (if any)
- before any public release: 
  - tighten the flatpak grant (currently --filesystem=home + --device=all)
  - **revert `sv_capture_maps` default to "0"** (temporarily "1" in dlls/game.cpp
    across all 3 hlsdk trees so we always capture map data while dogfooding)
  - documentation (see section below)


## Github Repositories

Umbrella project: https://github.com/bishopdynamics/Continuum
xash3d fork: https://github.com/bishopdynamics/xash3d-fwgs
mainui fork: https://github.com/bishopdynamics/mainui_cpp
hlsdk fork: https://github.com/bishopdynamics/hlsdk-portable


## Map capture & ingest (chapter thumbnails + loadouts)

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


### Deferred: non-linux platform suport

- windows: i dont have a machine to test, and I dont care
- macos: 32bit/64bit compatibility issues


### Deferred: FBO-based shadow map (resolution + soft blur) — NOT doing now

The flashlight shadow map currently renders the light's depth into a *corner of the
visible back-buffer* and copies it out (`glCopyTexSubImage2D`), so its resolution is
hard-capped to the window size (screen height). It is also desktop-GL-only
(`#if !XASH_GLES`).

Moving the shadow render into a real off-screen **FBO** (depth-texture attachment)
would:
- decouple resolution from the window (up to `GL_MAX_TEXTURE_SIZE`, e.g. 2048/4096)
  → crisper shadow edges
- enable a real, wide, *soft* shadow blur (the AO/entity-shadow features get their
  soft edges from a CPU box-blur of a fake-silhouette coverage bitmap; that trick
  does NOT transfer to the flashlight, whose shadow is a real hardware depth-compare
  — blurring that needs an FBO + blur pass, or expensive multi-tap PCF)
- also simplify/clean up the current render-into-corner + copy hack

Why deferred: it would be the renderer's **first FBO**. The rest of ref/gl is
deliberately FBO-free for portability (Deck / GLES / GLSL-risk). Platform risk is
actually low here (the shadow map is already desktop-GL-only, and we'd keep the
corner method as a fallback), but it's a real architectural line to cross and the
payoff is quality-only (the acne — the thing that looked bad — is already fixed).
Revisit only if we decide we want *soft* flashlight shadows; resolution alone isn't
worth it. One FBO buys both.
