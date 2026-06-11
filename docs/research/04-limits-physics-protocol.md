# Engine Limits, Server Physics/Collision, Network Protocol

> Code-dive findings, 2026-06-10. Line numbers approximate; re-verify before patching.

## 1. Headroom (good news — limits are not the problem)

| Limit | Value | Where |
|---|---|---|
| MAX_EDICTS (protocol) | 8192 (13 bits) | common/protocol.h:~116 |
| DEFAULT_MAX_EDICTS | 1200 (GoldSrc was 900) | common/defaults.h:~184 |
| MAX_MODELS | 4096 (12 bits) | common/protocol.h:~109 |
| MAX_SOUNDS | 2048 (11 bits) | common/protocol.h:~112 |
| MAX_VISIBLE_PACKET | 2048 ents/snapshot | common/protocol.h:~98 |
| Coordinates | float over the wire, no hard ±4096 clamp found | protocol 49 |

Two HL1 maps' worth of edicts/models/sounds fit comfortably. Whole-campaign precache
union likely also fits in 4096 models / 2048 sounds (worth verifying empirically).

## 2. Collision/physics

- Areanode tree (`sv_areanodes[32]`, depth 4) built once per level from
  `sv.worldmodel->mins/maxs` in `SV_ClearWorld` (sv_world.c:~461-477). Entities outside
  those bounds still link, but pile into the root node (perf, not correctness).
- **Per-entity BSP collision already exists**: `SV_ClipMoveToEntity` (sv_world.c:~830-951)
  selects hulls via `SV_HullForEntity`, supports SOLID_BSP entities with origin offset and
  even rotation. This is how func_door/func_wall/trains work. ⇒ A second map loaded as a
  SOLID_BSP entity at a translated origin would collide correctly through existing code.
- `SV_PointContents` (water/lava detection) is worldmodel-centric — water in a
  second-BSP-as-entity needs handling (GoldSrc handles func_water as entities already —
  verify how Xash routes contents for brush entities).
- Gravity/movement (pmove) shares the same trace machinery client+server.

## 3. PVS/networking

- `SV_AddEntitiesToPacket` (sv_frame.c:~52): per-client PVS/PHS from worldmodel via
  `pfnSetupVisibility`; per-edict leafnums cached by `SV_LinkEdict`.
- Entities outside the worldmodel / unknown leafs: fall back behavior to verify — likely
  always-sent or never-sent; either way a streaming system needs an explicit policy.
- `EF_MERGE_VISIBILITY` exists (portal-camera visibility merge, sv_frame.c:~155) — an
  existing hook for "render another area's entities".
- `svc_serverdata` + `svs.spawncount`: spawncount bump forces full client reinit
  (sv_client.c:~1545-1606). Seamless approaches must avoid bumping spawncount, or extend
  the protocol with an incremental "world add/remove" message.

## 4. Game DLL ABI constraints

- hlsdk assumes: edict 0 = worldspawn (CWorld), single `gpGlobals->mapname`, modelindex 1 =
  world BSP, `INDEXENT(0)` = world. A second worldspawn would need to be a different
  classname (e.g. a new "streamed world" entity) to avoid breaking CWorld logic
  (sky settings, global fog, CVAR setup happen in CWorld::Spawn).
- `gpGlobals->vecLandmarkOffset` (progdefs.h:~54) is the existing transition offset channel.
- Inline submodels: both BSPs define "*1","*2",... — name collisions in the precache
  string table. Needs namespacing (e.g. "maps/c1a1.bsp*3" style keys) or per-model
  submodel resolution instead of global string lookup.

## 5. Frank assessment (from this dive)

Tractable with existing mechanisms:
- Memory/limits headroom; per-entity BSP collision; brush-model rendering of a second BSP;
  landmark offset machinery; EF_MERGE_VISIBILITY precedent.

Hard parts:
- Single `sv.worldmodel` + areanode bounds; monolithic PVS; spawncount/client-reinit
  protocol coupling; hlsdk CWorld/edict-0 assumptions; submodel name collisions;
  renderer worldmodel singletons (VBO, lightmap atlas).
