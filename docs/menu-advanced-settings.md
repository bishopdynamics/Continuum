# Advanced Video Settings — curation for the Continuum menu

Reference for the Configuration → Advanced tab: which Xash3D cvars we expose,
how, and which we deliberately keep out. Inventory swept from `ref/gl/`,
`engine/client/`, and `engine/common/` on the streaming branch (2026-06-12);
stock mainui exposes only: gamma, brightness, r_detailtextures, gl_vbo,
r_ripple, gl_overbright, gl_texture_nearest/sw_texfilt, hud_scale, r_refdll,
fullscreen, vid_mode, gl_vsync.

Curation rule: a setting earns a row if a normal player could want to change
it AND the worst case is "looks different / runs slower", never "renders
wrong / crashes / needs console knowledge to undo". Everything else stays
console-only.

## Tier 1 — expose on the Advanced tab

### Textures
| Setting (UI label) | Cvar | Control | Notes |
|---|---|---|---|
| Anisotropic Filtering | `gl_anisotropy` | spinner Off/2x/4x/8x/16x | clamped to HW max in code |
| Texture Filtering | `gl_texture_nearest` | spinner Smooth/Nearest | Nearest = classic software-renderer look |
| Lightmap Filtering | `gl_lightmap_nearest` | spinner Smooth/Nearest | pairs with the above for the retro look |
| Detail Textures | `r_detailtextures` | toggle | default on |

### Lighting
| Setting | Cvar | Control | Notes |
|---|---|---|---|
| Overbright Lighting | `gl_overbright` | toggle | matches original GoldSrc look |
| Dynamic Lights | `r_dynamic` | toggle | muzzle flashes / explosions light the world |
| Entity Shadows | `r_shadows` | toggle | simple blob shadows, default off |
| Ambient Light | `r_lighting_ambient` | slider 0.0–1.0 | map ambient scale, default 0.3 |
| Extended Light Sampling | `r_lighting_extended` | toggle | light from world + bmodels, default on |

### Effects
| Setting | Cvar | Control | Notes |
|---|---|---|---|
| Water Ripples | `r_ripple` | toggle | software-renderer-style water |
| Lightmapped Water | `gl_litwater_force` | toggle | force even when map doesn't declare it |
| Decal Limit | `r_decals` | spinner 512/1024/4096/8192 | persistence of bullet holes / blood |

### Performance
| Setting | Cvar | Control | Notes |
|---|---|---|---|
| Frame Rate Limit | `fps_max` | spinner 60/72/100/120/144/165/240/Unlimited | default 72 is the GoldSrc-era value |
| Anti-Aliasing (MSAA) | `gl_msaa_samples` (+`gl_msaa`) | spinner Off/2x/4x/8x | **restart required** — GL context attribute |
| Widescreen FOV Correction | `r_adjust_fov` | toggle | could live on the basic Video tab instead |

### Interface tab (not Advanced, but newly exposed)
| Setting | Cvar | Control |
|---|---|---|
| FPS Counter | `cl_showfps` | toggle |
| Show Map Name | `scr_drawmapname` | toggle |

## Tier 2 — expose with a caution mark (amber styling, hint explains risk)

| Setting | Cvar | Control | Risk |
|---|---|---|---|
| Render Scale | `vid_scale` | spinner 1x/2x/3x/4x | pixelated retro upscale; vid restart; 4x on a small map = chunky but harmless |
| Mipmap Sharpness | `gl_texture_lodbias` | slider −2.0…0 | negative = sharper but shimmery; clamped to HW |

## Excluded — and why (so we don't relitigate)

- `gl_vbo`, `gl_vbo_detail`, `gl_vbo_dlightmode`, `gl_vbo_overbrightmode` —
  registration text itself says "known to be glitchy"; broken decal dlights in
  singlepass mode. Stock UI exposes gl_vbo; we drop it.
- `gl_keeptjunctions` (off = "blinking pixels"), `gl_nosort` (transparency
  artifacts), `gl_polyoffset*` (z-fighting tuning) — render-correctness
  footguns with no upside on modern GPUs.
- `gl_finish`, `gl_check_errors`, `sleeptime` — frame-pacing/debug knobs;
  invisible benefit, easy to hurt yourself.
- `gl_stencilbits`, `gl_round_down`, `gl_allow_extensions` — read-only or
  latched device config.
- `r_large_lightmaps` — latched, "might break custom renderer mods".
- `texgamma`, `lightgamma`, `direct` — change the authored look of every map;
  not archived; gamma/brightness sliders already cover user intent.
- `r_wadtextures`, `host_allow_materials`, `r_allow_wad3_luma` — content
  pipeline toggles for setups we don't ship.
- `r_pvs_radius` — interacts with our streaming/PVS work; ours to tune, not
  the user's.
- All FCVAR_CHEAT cvars (`r_fullbright`, `r_lightmap`, `cl_draw_particles`,
  `cl_draw_beams`, `cl_draw_tracers`, …) — blocked in multiplayer, won't
  persist, gameplay-affecting.
- Debug list (`r_novis`, `r_nocull`, `r_lockpvs`, `r_lockfrustum`,
  `r_showtree`, `r_speeds`, `net_graph*`, `cl_showpos`, software-renderer
  internals) — developer tooling.
- `mp_decals`, `viewsize`, `r_studio_*`, `hud_fontrender`, `hud_utf8` —
  legacy/compat, negligible user value.

## Implementation notes

- All Tier 1/2 GL cvars carry FCVAR_GLCONFIG or FCVAR_ARCHIVE → they persist
  automatically; the unified-config work just needs to route them to
  unified.cfg like everything else.
- FCVAR_VIDRESTART cvars apply live via VID_CheckChanges (GL context is
  preserved — verified earlier in the project). Only MSAA samples genuinely
  needs an engine restart; mark it in the UI the way the mockup shows.
- Every Advanced row needs a one-line hint (the focused-row hint slot) — that
  is where "what does this even do" lives, instead of a manual.
- Tab gets a "Restore Defaults" action (X button) scoped to the Advanced tab
  only.
