# M3 — World Residency Cache

> 2026-06-11. Engine change #2, all in engine/common/model.c.

## What changed

Parsed world models are no longer freed on changelevel. `Mod_PurgeStudioCache` now moves
the outgoing world into a side-cache (`worldcache_t` list) instead of freeing it:
a snapshot of `mod_known[0]`, all of its `*N` submodel entries, and the derived
`world_static_t` globals — with the world's memory pool ownership transferred to the
cache. `Mod_LoadWorld` checks the cache before loading: a hit restores slot #0,
recreates the submodel entries, and restores the globals — **skipping file I/O, BSP
parsing, and texture upload entirely** (renderer-side: brush model render data is only
freed via explicit `Mod_UnloadTextures`, which we never call for cached worlds, so GL
texture handles in `texture_t` stay valid; lightmaps/VBO are rebuilt per map by
`R_NewMap` as always).

Lifecycle safety:
- `Mod_FreeAll` (server shutdown) and `Mod_ClearUserData` (renderer restart — cached
  render data can't be recreated without the source buffer) purge the cache, clearing
  any mod_known slots that borrow a cached pool before freeing it (no double-free).
- Debug hull pointers (`world.hull_models`, r_showhull) are dropped at cache time.
- `mod_world_residency 0` restores legacy free-on-changelevel behavior.

## Verification

- Round trip c1a0 → c1a0d → c1a0: revisit `SV_SpawnServer` **34.6 ms → 0.51 ms (~68x)**;
  total server-side 46 → 23.6 ms. Screenshot on the revisited map renders correctly
  (textures/lightmaps intact after restore).
- 5-hop chain over 3 maps (c1a0→c1a0d→c1a0a→c1a0d→c1a0): multiple worlds cached,
  every restore ~0.5 ms, no crashes.
- Legacy regression (cvar 0): zero cache hits, stock timings (~32 ms), works.

## Current transition cost picture (modern PC, retail data)

| Component | First visit | Revisit (M3) |
|---|---|---|
| SV_SpawnServer (world load) | 22–50 ms | **~0.5 ms** |
| Save/restore + activate (M2 in-memory) | ~20 ms | ~20 ms |
| Client blackout window | ~120–155 ms | not yet measured separately |

Remaining big rocks for the swap: the save/restore entity round-trip itself, client
re-prep (R_NewMap/lightmaps/VBO/sound), and the reconnect machinery — all M4 targets.
M5 (preload) becomes trivial: walking the campaign graph warming the cache at startup
makes every map a "revisit".

## Notes / risks

- Memory: each cached world keeps its pool (~5–15 MB parsed) + GL textures resident.
  Whole HL1 campaign ≈ low hundreds of MB — within scope (RAM is free).
- MAX_MODELS (engine-side mod_known capacity) now fills with `*N` entries of the
  ACTIVE map only (cached worlds' submodels live in snapshots outside mod_known),
  so slot pressure is unchanged. Studio/sprite models still cycle normally.
- vid_restart / renderer switch drops the cache by design (next visits reload).
