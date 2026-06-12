# Resource-Probe Elimination (the two M4a "known items")

> 2026-06-11. Engine commit 98cf0614. Both leftover polish items from the M4a
> profiling closed; revisit transitions now server 7–8 ms / blackout ~21–25 ms.

## Decomposition first

Temporary `[prof2]` instrumentation showed the old bookkeeping was misleading:

- The "svc_resourcelist ~6 ms" item mostly *contained* the already-known ~4 ms
  client renderer prep — `CL_RegisterResources` (R_NewMap etc.) is called from
  inside the svc_resourcelist handler. The genuinely separate cost was
  `CL_EstimateNeededResources`: an `FS_FileExists` per resource (~400/map),
  ~2 ms.
- The "~9 ms server save/restore loop" item was actually dominated by
  `SV_CreateResourceList` inside `SV_ActivateServer`: `FS_FileSize` on every
  precached sound/model/event script, ~4 ms — filling download sizes. Every
  other `SV_ActivateServer` stage (pfnServerActivate, settle physics,
  CreateBaseline, consistency) measures ≤ 0.2 ms.

## Fixes (98cf0614)

- `SV_CreateResourceList`: skip the size probes when `maxclients == 1` —
  download sizes only matter when a remote client may download.
- `CL_EstimateNeededResources`: return 0 for local clients
  (`Host_IsLocalClient`) — the client shares the filesystem with its server;
  nothing the server just precached can be missing. Multiplayer/remote paths
  unchanged in both.

## Results (c1a0↔c1a0d revisit round trip)

| Metric | Before | After |
|---|---|---|
| Server-side total | 11–14 ms | **7–8 ms** |
| Client blackout | 27–31 ms | **21–25 ms** |

## What remains in a revisit transition

- `SaveGameState` ~2.5 ms + `LoadGameState` ~3–4 ms — the game DLL's entity
  serialization round-trip, i.e. the transition semantics themselves.
  Eliminating it means handing live entities across the swap without
  serialization — Phase 2 atomic-swap territory, not polish.
- ~4 ms client renderer prep (R_NewMap lightmaps/VBO) — per-map by design.

Both M4a follow-up items are closed; transitions are within ~1.3 frames at
60 Hz with sound continuity.
