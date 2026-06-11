# M0 — Build, Bring-up & Baseline Changelevel Measurements

> 2026-06-11. Machine: Linux amd64, NVIDIA RTX 3060, fast NVMe (/mnt/Fast), warm FS cache.

## Build setup (reproducible)

- SDL2 2.30.11 built from source into `.deps/sdl2` (no system dev package; runtime lib present).
- Engine: `xash3d-fwgs$ ./waf configure -T release -8 --sdl2=<abs path>/.deps/sdl2 && ./waf build && ./waf install --destdir=../install`
  (64-bit: no multilib gcc on this box; we build hlsdk 64-bit ourselves so this is fine.)
- Game DLL: `hlsdk-portable$ ./waf configure -T release -8 && ./waf build`
  → `build/dlls/hl_amd64.so`, `build/cl_dll/client_amd64.so` → installed into `<gamedir>/dlls`, `<gamedir>/cl_dlls`.
- Game data for testing: **HL "Day One" demo** (freely distributed; archive.org item
  `hl_shareware_data`, `valve/dayone.zip` + `delta.lst`/`valvecomm.lst` from `valve/hlds.zip`)
  → `install/dayone/` with `pak0.pak` (first 27 campaign maps, c0a0–c1a3d, textures embedded)
  and a minimal hand-written `liblist.gam`. Retail `valve/` data from James still wanted for
  full-campaign measurements (demo lacks later chapters' assets; hlsdk precache of missing
  retail weapon models logs non-fatal errors).
- Gotchas hit: engine requires `liblist.gam` to recognize a game dir; requires `delta.lst`
  (not in the 1998-era demo); dedicated console reads stdin (run with `< /dev/null` when
  scripted); scripted testing via `maps/<map>_load.cfg` hook + `wait`-chains works well.

## Instrumentation added (both in engine, marker `[streamprof]`)

- `engine/server/sv_save.c` `SV_ChangeLevel()`: per-stage wall time — SaveGameState,
  Teardown (InactivateClients+FinalMessage+DeactivateServer), SV_SpawnServer,
  LoadGameState, LoadAdjacentEnts, SV_ActivateServer, TOTAL.
- `engine/client/cl_scrn.c`: client blackout = SCR_BeginLoadingPlaque → SCR_EndLoadingPlaque.

## Results — smooth (singleplayer) changelevel c0a0 → c0a0a, listen client, GL renderer

| Stage | Time |
|---|---|
| SaveGameState (entity serialize + .HL1/.HL2 disk write) | 3.00 ms |
| Teardown (deactivate server, free edicts/strings) | 0.04 ms |
| SV_SpawnServer (BSP load + submodels + clearworld) | 22.72 ms |
| LoadGameState (read .HL1, restore entities) | 3.54 ms |
| LoadAdjacentEnts (adjacent .HL1s, landmark offset restore) | 0.24 ms |
| SV_ActivateServer (baselines, resource list, activate) | 4.92 ms |
| **TOTAL server-side** | **34.6 ms** |
| **Client blackout (loading plaque visible window)** | **108 ms** |

Dedicated classic changelevel (no save/restore): ~19 ms total server-side.

## Results — RETAIL data (2026-06-11), c2a5e → c2a5f (the two heaviest maps: 635/719 ents)

| Stage | Time |
|---|---|
| SaveGameState | 4.38 ms |
| Teardown | 0.26 ms |
| SV_SpawnServer | 44.50 ms |
| LoadGameState | 15.76 ms |
| LoadAdjacentEnts | 0.86 ms |
| SV_ActivateServer | 5.84 ms |
| **TOTAL server-side** | **71.7 ms** |
| **Client blackout** | **124.9 ms** |

Retail valve/ now in install/ (444 MB, 115 maps); our amd64 game DLLs copied into
valve/dlls + valve/cl_dlls. Worst-case retail transition stays ~order-100 ms total —
confirms the demo-data conclusion. Note: on a listen server the client blackout window
CONTAINS the server-side work (single thread), so the pure client re-prep cost is
~50–80 ms; instrumenting inside that window (R_NewMap/lightmaps/VBO/sound re-prep) is the
next profiling step when designing the atomic swap (M4).

## What this changes about our priors

1. **On modern hardware the data is already nearly free.** The multi-second loading
   screens of lore are old-disk/old-CPU artifacts plus retail asset sizes. Here the whole
   server-side transition is ~35 ms and the user-visible blackout ~108 ms.
2. **The perceived problem is the machinery, not the I/O**: deliberate plaque +
   `cls.disable_screen`, S_StopAllSounds hard cut, effects wipe, client re-prep
   (video/audio_prepped), prediction reset — i.e., exactly the Phase 1 "atomic swap"
   target list. Async loading infrastructure may matter less than assumed for HL1-scale
   data; **removing teardown/reinit is the whole game.**
3. Caveats before over-trusting these numbers: demo maps are small (1–2 MB vs retail max
   3.5 MB), early maps have few entities/monsters, warm cache, very fast machine, and the
   client asset re-prep cost will grow with retail textures/models/sounds. Re-measure on
   retail data across heavyweight transitions (e.g., c2a5 chain) once available — but the
   order of magnitude is unlikely to change on target hardware.

## Next (M1+)

- Get retail `valve/` data dropped in for full-campaign measurements (esp. heavy maps and
  a transition while monsters are active).
- Optionally instrument inside the 108 ms client window (what dominates: re-prep,
  resource list, renderer R_NewMap/lightmaps?) before designing the swap.
- Proceed to M1 preprocessing tool (map graph extraction) — independent of game data
  questions, validated against gamedata/maps retail BSPs.
