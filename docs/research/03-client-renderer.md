# Client & Renderer Side (xash3d-fwgs, ref_gl)

> Code-dive findings, 2026-06-10. Line numbers approximate; re-verify before patching.

## 1. Ref API boundary

- `REF_API_VERSION 17` (engine/ref_api.h). Renderer is a separate dll (ref/gl, ref/soft).
- Engine→renderer world handoff: `ref_client_t.models[]`; **models[1] is the worldmodel**.
- `R_NewMap()` (ref/gl/gl_context.c:~399): sets `tr.worldmodel = gp_cl->models[1]`, clears
  decals, clears efrags/texturechains, `GL_BuildLightmaps()`, `R_GenerateVBO()`.

## 2. Single-world assumptions in the GL renderer

- `#define WORLDMODEL (tr.worldmodel)` (ref/gl/gl_local.h:~700) — used in ~50 places.
- `R_DrawWorld` → `R_RecursiveWorldNode(WORLDMODEL->nodes, ...)` (gl_rsurf.c:~3667, ~3451):
  walks the single world BSP, builds texture chains, global `skychain`.
- Lightmaps: ONE atlas set `tr.lightmapTextures[MAX_LIGHTMAPS]`, fully freed + rebuilt per
  map in `GL_BuildLightmaps` (gl_rsurf.c:~3886) — but note it iterates **all brush models**
  (`for i < gp_cl->nummodels ... GL_CreateSurfaceLightmap`), so lightmapping a second BSP's
  surfaces is structurally possible if both are resident when it runs.
- VBO: `R_GenerateVBO` (gl_rsurf.c:~2125) sized to `WORLDMODEL->numsurfaces`; surface→VBO
  lookup is pointer arithmetic `(surf - WORLDMODEL->surfaces)` — breaks for second BSP.
  `R_DrawBrushModel` (gl_rsurf.c:~1817) sets `allow_vbo = false` when
  `clmodel->surfaces != WORLDMODEL->surfaces` → **external/second BSPs already render via the
  non-VBO brush-model path**. Slower but functional.
- PVS: `R_MarkLeaves` uses `Mod_PointInLeaf(origin, WORLDMODEL->nodes)` + worldmodel visdata.

**Important existing capability:** the renderer can already draw a *different BSP file* as
a brush-model entity (this is how some games use external .bsp models). Lightmaps, sky,
water, decals on it have caveats, but the basic "render a second BSP as an entity" path
exists.

## 3. Client state machine

- `client_t cl` holds `models[]`, `worldmodel`, `servercount` (spawncount), precaches,
  lightstyles (engine/client/client.h:~173).
- `CL_ParseServerData` (cl_parse.c:~768): unless `cls.changelevel`, runs `CL_ClearState()`
  → `memset(&cl, 0)`, `S_StopAllSounds`, `CL_ClearEffects` (temp ents, beams, particles,
  dlights), `CL_FreeEdicts`, `PM_ClearPhysEnts`.
- With `cls.changelevel` set, the wipe is skipped, but video/audio still get re-prepped and
  the world is still replaced.

## 4. Visible discontinuities during today's changelevel

1. Loading plaque: `SCR_BeginLoadingPlaque` → `cls.disable_screen` (no last-frame hold,
   hard cut to plaque/black).
2. Audio: `S_StopAllSounds(true)` — hard stop, no fade; music stopped if !changelevel.
3. All effects wiped (decals, particles, beams, temp ents, dlights).
4. Prediction reset; pmove physents cleared.
5. View weapon: `cl.local.viewmodel` index may go stale across precache change.

## 5. Sound

Sound precache reloaded per map; ambient/looping sounds restart via .HL2 restore
(server-side restore of sounds exists in LoadClientState — continuity machinery partially
exists for saves).

## 6. What breaks with two resident worlds (renderer)

| Item | Severity | Note |
|---|---|---|
| tr.worldmodel / WORLDMODEL macro | critical | single pointer, ~50 sites |
| VBO surface indexing | critical | pointer arithmetic off worldmodel surfaces; but non-VBO path exists |
| Lightmap atlas lifecycle | high | rebuilt per map; would need incremental add or rebuild-on-stitch |
| skychain / skybox | high | one sky active; adjacent HL maps mostly share sky though |
| Decal pool | high | keyed to model pointers; cleared in R_NewMap |
| PVS / R_MarkLeaves | high | single visdata; for cross-map vis would need portal hack or distance cull |
| Efrags (static ents in leafs) | medium | per-leaf lists, per-world |
