# Improved Flashlight — Design & Implementation Notes

Status: **Phase 1 in progress** (2026-06-13). One of the "Insane things" from Notes.md.
Default-OFF experimental feature. Validated on Office Complex (`c1a2`) — dark rooms + ducts.

## Goal

Replace the stock flashlight (a single round point-dlight dropped at a forward
trace hit, lighting the world by CPU lightmap-texel recompute — no cone, no
beam, no occlusion) with a real **projected-texture spotlight** (Phase 1) that
later **casts dynamic shadows** via a shadow map (Phase 2).

Baseline hardware = Steam Deck (RDNA2), which has ample headroom: one spotlight
is the cheapest possible case for both techniques (one frustum, one depth pass).

## What the renderer already gives us (decisive findings)

`ref/gl` is a forward, mostly fixed-function GL renderer (GLSL only exists as the
`gl2_shim`/`vgl_shim` FFP-emulation layer — there is **no general custom-shader
framework**). So we implement with **fixed-function** calls, which then ride the
shim automatically on ES2/core → works on the Deck from one implementation.

- `GL_TexGen(S/T/R/Q, mode)` + `GL_DisableAllTexGens` — `gl_backend.c:217,327`.
- `GL_LoadTexMatrixExt(glmatrix)` loads the per-TMU texture matrix — `gl_backend.c:102`.
- `GL_SelectTexture` / `GL_Bind` / `GL_MultiTexCoord2f` multitexture — `gl_backend.c`.
- `TF_BORDER` = "zero clamp for projected textures": `GL_CLAMP_TO_BORDER`, black
  border `(0,0,0,1)`, auto-fallback to `TF_CLAMP` if unsupported — `gl_image.c:151-174`.
- `TF_DEPTHMAP` wires ARB_shadow compare (`GL_COMPARE_R_TO_TEXTURE`, `GL_LEQUAL`,
  depth mode `INTENSITY`) — `gl_image.c:123-138`. This is half of Phase 2, ready.
- `GL_CreateTexture(name,w,h,buffer,flags)` — raw texture creator (`gl_local.h:330`).
- `GL_FrustumInitProj` + `GL_FrustumCullBox/Sphere` — `gl_frustum.h`.
- `pglClipPlane`, `pglCopyTexSubImage2D`, matrix funcs — all present in `gl_export.h`.
- View state in the ref: `RI.rvp.vieworigin`, `RI.vforward/vright/vup`
  (`gl_rmain.c:347`). Flashlight on/off = local player's `EF_DIMLIGHT`:
  read `gEngfuncs.GetEntityByIndex( gp_cl->viewentity )->curstate.effects`
  (`gp_cl` is `ref_client_t`, exposes `viewentity`/`playernum` — `ref_api.h:184`).

`wscript` globs `*.c`, so a new `ref/gl/gl_flashlight.c` is auto-built.
No FBO function pointers are loaded in `ref/gl` (only `ref/soft` uses FBO) → Phase 2
uses the **no-FBO** shadow-map technique (render depth into the main framebuffer,
`glCopyTexSubImage2D` into a depth texture).

## Phase 1 — projected-texture cookie spotlight (ref/gl only)

Pure `ref/gl` change. We keep the engine's existing `EF_DIMLIGHT` point-dlight
(so studio models / monsters still get lit for free) and **overlay** a cookie
cone on the world. Minor double-bright at the hit point is acceptable for now.

### Cvars (registered next to `r_shadows` in `gl_opengl.c`)
| cvar | default | meaning |
|---|---|---|
| `r_flashlight_projected` | `0` | master toggle for the new flashlight |
| `r_flashlight_cone` | `45` | full cone angle, degrees |
| `r_flashlight_range` | `1500` | max beam distance, units |
| `r_flashlight_intensity` | `1.0` | brightness multiplier |
| `r_flashlight_albedo` | `1` | modulate cone by surface texture (vs flat add) |
| `r_flashlight_shadows` | `0` | Phase 2: cast dynamic shadows |

### Math (built as GL column-major `float[16]`, loaded into the texture matrix)
- `Vl` = lookAt(origin, origin+forward, up)   — world → light view
- `Pl` = perspective(fovy=cone, aspect=1, near≈4, far=range) — light view → clip
- `Bias` = clip `[-1,1]` → `[0,1]`:
  `diag(0.5,0.5,0.5)` + translate `(0.5,0.5,0.5)`
- **Texture matrix** `T = Bias · Pl · Vl`.

Texgen `S,T,R,Q` = `GL_OBJECT_LINEAR` with **identity object planes**, so the
generated coord = the vertex's object-space position `(x,y,z,1)`. For world
surfaces object space = world space, so `T·(x,y,z,1)` = projected cookie coords;
the texture unit divides `s,t` by `q` (projective texturing) before the lookup.

### The additive pass (end of `R_RenderScene`, after opaque world+entities)
1. Bail unless `r_flashlight_projected` and the view entity has `EF_DIMLIGHT`.
2. State: `glBlendFunc(GL_ONE,GL_ONE)` additive, `glDepthFunc(GL_LEQUAL)`,
   `glDepthMask(FALSE)`, small `GL_PushPolygonOffset` to beat z-fighting with the
   base pass, face cull as world.
3. **Back-projection fix**: a user clip plane (`GL_CLIP_PLANE0`) at the light's
   position facing `forward`, so geometry behind the lens is excluded from the
   pass (kills the reverse "mirror" cone at the apex).
4. Cookie unit: bind cookie (TF_BORDER), texgen on, load `T`, env `MODULATE`.
   Optional albedo unit (TMU0) = surface base texture with its real `(s,t)`.
5. Iterate `WORLDMODEL->surfaces`, keep `surf->visframe==tr.framecount`, skip
   sky/turb/tiled, frustum-cull `surf->info` bbox against the spot frustum, emit
   `surf->polys` verts in immediate mode. Per vertex compute a CPU distance
   attenuation `atten = clamp((range-d)/range,0,1)^2`, `d = dot(v-origin,forward)`
   (`atten=0` behind), and `glColor4f(color*atten…)`. The cookie supplies the
   per-fragment cone falloff; `atten` supplies smooth distance falloff.
6. Restore all state (`GL_CleanUpTextureUnits`, identity tex matrix, disable clip
   plane, depthMask true, pop polygon offset).

### Known Phase-1 limitations (documented, not bugs)
- World + brush-model surfaces receive the cone; **studio models** (monsters,
  props) are still lit only by the retained point-dlight, not the cookie. Adding
  studio cookie-receive is a follow-up.
- Distance attenuation is per-vertex (Gouraud) — coarse on very large polys, fine
  for a flashlight. Cone shape is per-fragment (cookie), so it stays crisp.

## Phase 2 — dynamic shadows via a no-FBO shadow map (experimental, cvar-gated)

Gated behind `r_flashlight_shadows`. One spotlight → one shadow map.

1. Create a `TF_DEPTHMAP` depth texture (e.g. 1024², fits in the Deck's 1280×800
   back buffer) once per map/size.
2. Each frame the flashlight is on: set viewport to a `size×size` corner of the
   **main framebuffer**, set the GL projection/modelview to `Pl·Vl`, render the
   world (and ideally studio) **depth only** (no color, color mask off) with a
   front/back polygon-offset to fight acne, then `glCopyTexSubImage2D` the depth
   into the depth texture. Clear that corner's depth before the real scene, or do
   the shadow pass before `R_Clear`.
3. In the cookie pass, bind the depth texture on an extra TMU with the same
   projective texgen but its texture matrix also carrying the `r` (depth) row;
   ARB_shadow compare returns 0/1 (lit/shadowed) in `INTENSITY`, which modulates
   the cookie contribution. Result: the beam is occluded by walls/ducts.

Studio depth submission can reuse the `R_StudioDrawPointsShadow` pattern
(`gl_studio.c:2589`). Start with **world-only** shadow casting (walls/ducts are
the dominant occluders in `c1a2`), add studio casters next.

## Test plan
- Map `c1a2` (Office Complex): dark side rooms + the vent/duct network.
- Compare `r_flashlight_projected 0` (stock round blob) vs `1` (cone+cookie).
- Watch for: back-projection mirror cone (clip plane), z-fighting shimmer
  (polygon offset), cone leaking through walls (expected until Phase 2),
  performance (`r_speeds`).
- Phase 2: stand so a duct lip / doorframe is between you and a wall; the beam
  should show a hard shadow edge.

## STATUS (2026-06-13)

### Phase 1 — DONE and validated ✅
Validated in-engine on `c1a2`: the cookie cone projects on world surfaces,
albedo-modulated, composites additively, aims with the view, and the cvars work
live. Fixed a TMU state-leak found during validation (cookie leaked onto the
lightmap unit → whole scene multiplied by the black-bordered cookie; fixed with
`GL_CleanupAllTextureUnits`). This is the shippable feature.

### Phase 2 — implemented, builds, non-destructive; shadow quality needs interactive tuning ⚠️
The full pipeline is in place and `r_flashlight_shadows 1` runs without crashing
or corrupting the scene. The depth machinery is confirmed working (before bias
tuning it produced classic depth-based self-shadow **acne** — i.e. the depth
render + ARB compare are functioning). What remains is the acne-vs-peter-panning
bias tradeoff and confirming clean *cast* shadows at occluder-rich vantages —
which needs a human at the controls (autonomous nav couldn't reach a controlled
doorway/duct vantage; noclip kept embedding in geometry; flat-surface views have
no occluder to shadow). Left **default-off**.

Key insight discovered during validation — **a head-mounted light hides its own
shadows.** With the light exactly at the eye, every surface the camera sees is
also lit (shadows fall behind their casters, invisible to the viewer — the
headlamp problem). So the light is offset off the eye via `r_flashlight_offset`
(default 16, down + slightly right, like a chest-held flashlight). Raise it
(32–80) to make shadows more visible while tuning.

Tuning knobs that matter for Phase 2 (all in `gl_flashlight.c`):
- `FL_NEAR` (24): the near plane. A small near (was 4) gives a 350:1 near/far
  ratio that destroys shadow-map depth precision → grainy acne everywhere.
  24 brings it to ~60:1. Could also fit near/far to the visible scene each frame.
- shadow-pass `GL_PushPolygonOffset` (1.0, 2.0): the depth bias. Too low → acne;
  too high → peter-panning (shadows vanish — what over-tuning to 3.0/6.0 did).
- `r_flashlight_offset`: parallax; 0 = no visible shadows (co-located), bigger =
  more visible shadows but cone drifts further from the crosshair.
- A single global polygon-offset over a 24–1600u range is a fundamentally hard
  bias problem; slope-scaled bias + a per-frame scene-fit near/far would make it
  robust. Studio-model (monster/prop) shadow casters are also still TODO — the
  depth pass renders world surfaces only.

To validate by hand: enable `sv_cheats 1`, `impulse 101` (suit), `impulse 100`
(flashlight), `r_flashlight_projected 1`, `r_flashlight_shadows 1`,
`r_flashlight_offset 48`, then stand in a doorway looking through it at the
floor/wall beyond — the doorframe should cast a shadow. Tune the polygon offset
in code if you see acne or missing shadows.
