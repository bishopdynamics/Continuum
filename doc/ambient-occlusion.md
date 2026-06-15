# Ambient occlusion

Continuum adds supplemental ambient occlusion — soft contact shadowing that
grounds characters and props and deepens the corners of the world. It's on by
default; both systems can be toggled and tuned independently.

## Two systems

**Entity contact AO** (`r_ao`) — a soft contact shadow under moving entities and
props: monsters, the player, physics props. By default it's projected from the
model's silhouette with a soft penumbra, and fades out as the entity lifts off
the floor, so things feel planted instead of floating.

**Baked world AO** (`r_ao_world`) — corner and recess shading baked into the
level geometry: doorways, alcoves, and the seams between surfaces pick up subtle
occlusion that the stock lightmaps don't carry.

The two are independent — you can run either one alone.

## Baking

World AO is **baked offline, once per map**, the first time you launch, and
cached to disk. Normal play then just loads the cache, so there's no per-map
bake hitch during a session. If you change a setting that affects the bake (e.g.
`r_ao_world_dist`), the affected maps re-bake. To force a full rebuild of every
map's cache, run the `r_ao_bake_all` command.

## Tuning it

See the [ambient-occlusion cvars](cvars.md#ambient-occlusion) for the full list.
Common tweaks:

- **Overall strength** — `r_ao_strength` (entities) and `r_ao_world_strength`
  (world). Set `r_ao 0` / `r_ao_world 0` to disable either system.
- **Contact softness / size** — `r_ao_soft` (penumbra width) and `r_ao_size`
  (footprint scale).
- **Bake quality** — `r_ao_world_dist` (longer rays = more occlusion, re-bakes
  the cache).
