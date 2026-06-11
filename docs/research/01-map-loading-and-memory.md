# Map Loading Path & Memory Model (xash3d-fwgs)

> Code-dive findings, 2026-06-10, against fresh clone of FWGS/xash3d-fwgs master.
> Line numbers are approximate (agent-surveyed); re-verify before relying on them in patches.

## 1. Server-side load path (fully synchronous, single-threaded)

```
SV_SpawnServer(mapname, startspot)                 engine/server/sv_init.c:~932
├─ SV_SetupClients / SV_InitGame (load server dll)
├─ Delta_Init, Host_SetServerState(ss_loading)
├─ memset(&sv, 0, ...)                              — wipes entire per-level struct
├─ Mod_LoadWorld(mappath)                           — BSP load (below)
├─ CRC32_MapFile                                    — map CRC
├─ Mod_ForName("*i") for each submodel              — inline brush models
├─ SV_InitEdict × maxclients
├─ SV_UpdateMovevars
├─ SV_ClearWorld()                                  sv_world.c — areanodes from worldmodel bounds
└─ (caller) SV_SpawnEntities → SV_LoadFromFile      sv_game.c — parse entity lump, pfnSpawn per entity
└─ SV_ActivateServer                                sv_init.c:~578
   ├─ pfnServerActivate
   ├─ SV_Physics × 2-8 frames (settle)
   ├─ SV_CreateBaseline, SV_CreateResourceList, SV_TransferConsistencyInfo
   └─ Host_SetServerState(ss_active)
```

## 2. BSP loading

`Mod_LoadBrushModel` (engine/common/mod_bmodel.c:~4404):
- `Mem_AllocPool(per-model pool)` then `Mod_LoadBmodelLumps` loads ALL lumps synchronously:
  vertices, planes, nodes/leafs, clipnodes (3 collision hulls), surfaces/edges/texinfo,
  lightdata, visdata (RLE PVS, decompressed on demand), entdata (raw entity string).
- OpenMP (`#pragma omp` in mod_bmodel.c:~3677) is used ONLY for post-load processing
  (leaf/hull work), not I/O.
- On world load, sets global `worldmodel` pointer.

## 3. Memory model

- Zone/pool allocator (engine/common/zone.c). **Per-model pools**, not a per-level hunk.
- `model_t mod_known[]` cache (engine/common/model.c); freed via `Mod_FreeModel` /
  `Mod_FreeUnused` / `Mod_FreeAll` — nothing auto-clears per level.
- `svgame.mempool` (server edicts zone), `svgame.stringspool` (entity strings) emptied in
  `SV_DeactivateServer` (sv_init.c:~681).
- Implication: keeping a second BSP resident is memory-feasible by simply not freeing it;
  the pool design doesn't fight us.

## 4. Single-world singletons (the core problem)

| Singleton | Where | Role |
|---|---|---|
| `sv.worldmodel` | engine/server/server.h | THE world: hulls, lightdata, visdata, entities, BSP tree |
| `world` (world_static_t) | engine/common/mod_local.h:~89 | extents, visbytes, compressed PHS, deluxe/shadow data, wadlist |
| `sv_areanodes[32]` | engine/server/sv_world.c:~43 | entity link tree, built from `sv.worldmodel->mins/maxs` in `SV_ClearWorld` (sv_world.c:~476) |
| PVS queries | `Mod_GetPVSForPoint`, `Mod_FatPVS` (mod_bmodel.c:~1138, ~1202) | hardcoded to worldmodel |

## 5. Client-side load path

`CL_ParseServerData` (engine/client/parse/cl_parse.c:~771):
- Unless `cls.changelevel`: `CL_ClearState()` (full wipe of `cl`), `CL_InitEdicts`, stop music.
- CRC-check local BSP vs server, set `cl.video_prepped = cl.audio_prepped = false`,
  request loading plaque.
- `SCR_BeginLoadingPlaque` (engine/client/cl_scrn.c:~494): `S_StopAllSounds`, draw plaque,
  `cls.disable_screen = host.realtime` freezes screen updates.
- Resources via svc_resourcelist → download/verify → renderer + sound load models/textures.

## 6. Async infrastructure

**None.** No worker threads, no job queue, no async FS. All `FS_LoadFile` calls block the
main thread. Any background loading is ours to build (or to sidestep by preloading).

## 7. Rough cost profile of a load (typical HL1 map, modern PC)

- BSP read+parse: hundreds of ms; lightdata copy is the biggest lump.
- Entity parse + pfnSpawn loop: ~0.1–1s depending on entity count.
- Physics settle + baselines + resource list: tens of ms.
- Engine prints `level loaded at X.XX sec` (sv_init.c:~665) — easy instrumentation hook.

## Key takeaway for streaming

Everything below `SV_SpawnServer` assumes one world, but the *memory layer* (per-model
pools, mod_known cache, 4096 model slots) would tolerate multiple resident BSPs today.
The blockers are the spatial/visibility/collision singletons, not RAM or the allocator.
