# Console variable reference

Every cvar and command **added** by Continuum on top of upstream Xash3D-FWGS.
Everything the stock engine already provides is unchanged and documented
upstream — this page only covers what's new here.

Set any of these from the in-game console (`~`), from a `.cfg`, or on the
command line (`+r_ao_world 0`). Most are also surfaced in the
[settings menu](menu.md), so you rarely need the console for day-to-day use.

> Defaults below are the engine's actual defaults. A few features (level
> streaming, ambient occlusion) ship **on** because they *are* the Continuum
> experience; the more cosmetic extras (projected flashlight) ship **off**.

## Level streaming & transitions

These drive the no-loading-screen campaign. The defaults are tuned for the
seamless experience — turning them off gets you closer to stock behaviour.

| cvar | default | values | what it does |
|------|---------|--------|--------------|
| `cl_seamless_changelevel` | `1` | 0 / 1 | No loading plaque on a transition — the last frame stays on screen during the swap. |
| `sv_transition_memstate` | `1` | 0 / 1 | Keep changelevel transition state in memory instead of writing `save/*.HL?` disk files. |
| `sv_transition_sounds` | `1` | 0 / 1 | Resume sounds on entities that cross a transition (NPC speech, weapons, suit VOX) at their exact saved sample position. |
| `mod_world_residency` | `1` | 0 / 1 | Keep parsed world models resident across changelevels so revisited maps restore instantly instead of reloading from disk. |
| `scr_drawmapname` | `1` | 0 / 1 | Draw the current map name in the bottom-right corner while in game. |

**Commands**

| command | what it does |
|---------|--------------|
| `world_preload <mapname>` | Load a map into the residency cache ahead of time. Requires `mod_world_residency 1` and no running server. (The engine does this automatically for the whole campaign behind the menu.) |

## Flashlight

The optional projected-texture flashlight. With `r_flashlight_projected 0`
(the default) you get the stock dynamic-light flashlight; set it to `1` to
enable the projected cookie + shadows described in [flashlight.md](flashlight.md).

| cvar | default | values | what it does |
|------|---------|--------|--------------|
| `r_flashlight_projected` | `0` | 0 / 1 | Enable the projected-texture flashlight (beam + spill + shadows). |
| `r_flashlight_cone` | `35` | 2–170° | Beam (hotspot) cone angle in degrees. |
| `r_flashlight_intensity` | `3.0` | ≥0 | Beam brightness. Each whole unit is one additive pass. |
| `r_flashlight_spill_cone` | `90` | beam–175° | Spill cone angle — the wider, dimmer halo around the beam. |
| `r_flashlight_spill_intensity` | `0.15` | 0–1 | Spill brightness as a fraction of the beam intensity. |
| `r_flashlight_range` | `3000` | ≥64 | Maximum reach in world units. |
| `r_flashlight_albedo` | `1` | 0 / 1 | Modulate the cone by the surface texture (`1`) or flat-add white (`0`). |
| `r_flashlight_shadows` | `1` | 0 / 1 | Dynamic shadow mapping for the beam. |
| `r_flashlight_shadow_size` | `512` | 256–4096 | Shadow-map resolution in texels (square; clamped to the backbuffer). Higher = crisper edges, more GPU cost. |
| `r_flashlight_offset` | `4` | −20–20 | Vertical light offset from the eye; positive lifts it above the head for parallax. |
| `r_flashlight_debug` | `0` | 0 / 1 | Visualise the raw projected cookie (debugging). |

## Ambient occlusion

Two independent systems: **contact AO** (soft shadows under moving
entities/props) and **world AO** (baked corner/recess shading on the level
geometry). See [ambient-occlusion.md](ambient-occlusion.md).

### Entity contact AO

| cvar | default | values | what it does |
|------|---------|--------|--------------|
| `r_ao` | `1` | 0 / 1 | Enable contact AO — soft contact shadows under monsters and props. |
| `r_ao_strength` | `0.5` | 0–1 | Contact-AO darkness under entities. |
| `r_ao_size` | `1.1` | multiplier | Footprint scale relative to the model bounding box. |
| `r_ao_fade` | `72` | units | Height over the floor at which contact AO fully fades out. |
| `r_ao_silhouette` | `1` | 0 / 1 | Shape: projected model silhouette (`1`) or a soft blob (`0`). |
| `r_ao_soft` | `2` | units (0 = hard) | Silhouette penumbra width — edge softness. |
| `r_ao_height` | `16` | units | Contact height falloff: parts fade from the floor over this distance. |
| `r_ao_ground_dot` | `0.7` | 0–1 | Minimum upward floor-normal to accept; steeper hits skip AO. |
| `r_ao_debug` | `0` | 0 / 1 | Draw contact-AO footprints as solid purple (debugging). |

### Baked world AO

World AO is baked offline (per map) the first time you launch and cached, so
there is no per-map bake hitch in normal play.

| cvar | default | values | what it does |
|------|---------|--------|--------------|
| `r_ao_world` | `1` | 0 / 1 | Enable baked world AO — corner/recess shading on BSP geometry. |
| `r_ao_world_strength` | `0.6` | 0–1 | World-AO darkness intensity. |
| `r_ao_world_max` | `0.6` | 0–1 | Cap on maximum occlusion (keeps tight gaps from slamming to black). |
| `r_ao_world_dist` | `64` | ≥8 units | Occlusion ray length — bake quality. Changing it re-bakes the cache. |
| `r_ao_world_debug` | `0` | 0 / 1 | Show baked world AO as hot pink in the lightmap (live, no re-bake). |
| `r_ao_autobake` | `1` | 0 / 1 | Auto-bake any missing world-AO caches at campaign launch. |

**Commands**

| command | what it does |
|---------|--------------|
| `r_ao_bake_all` | Re-bake the world-AO caches for every map in the current game. |
