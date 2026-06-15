# Notes

## Remaining roadmap to v1 release

- macos universal build still needs a Mac (tools/build_all.sh prints guidance)
- win32+wine controller hotplug unreliable — needs a real-Windows test
- rebuild + reship the dist artifacts (linux-amd64 tarball + flatpak) so they include all the menu changes (HD toggle, cheats, flashlight)
- before any public release: 
  - tighten the flatpak grant (currently --filesystem=home + --device=all)
  - demos and videos (see section below)
  - documentation (see section below)


## Demos and videos

Decisions (2026-06-14): **external screen-grab now, engine frame-dump later**;
the final gameplay cut waits until the AO preload bake commits. Env: X11,
ffmpeg 7.1 already installed → `ffmpeg -f x11grab` covers it, no new deps
(GIF via ffmpeg `palettegen`/`paletteuse`, no gifski needed). Engine has NO
`startmovie`/frame-dump — only single-frame `screenshot` — hence method A first.

Two deliverables, two scripts in `tools/`:

1. **Menu tour → GIF** (`tools/capture-menu-gif.sh`) — UNBLOCKED, do first.
   - Launch `./play-continuum.sh -windowed` at a fixed size (e.g. 1280x720) so
     the grab region is deterministic.
   - `ffmpeg -f x11grab -framerate 10 -video_size 1280x720 -i :0+<x>,<y>` for a
     fixed duration; two-pass GIF (`palettegen` → `paletteuse`,
     `fps=10,scale=...:flags=lanczos`).
   - No demo drives the menu, so navigation is a hand-driven take; the script
     just standardizes window size + encode so re-shoots look identical.
   - Output → `docs/media/menu-tour.gif`, referenced from the README (small
     enough to commit).

2. **Gameplay demo → 30fps MP4** (`tools/capture-demo-video.sh`) — GATED on the
   AO preload bake committing + a re-record.
   - The demofile already exists: `demos/cascade.dem` (committed de2f9b7) — one
     continuous run, opening tram ride → just past the resonance cascade, across
     every level transition. `demos/README.md` documents playback.
   - Script wraps playback (`play-continuum.sh valve +playdemo cascade`,
     windowed fixed size) and grabs it: `ffmpeg -f x11grab -framerate 30` →
     H.264 MP4 (`-crf 18 -preset slow -pix_fmt yuv420p`). This IS the
     re-capturable pipeline: dem in → video out, one command.
   - Method A is a real-time grab, so playback must run clean → **re-record
     `cascade.dem` after the front-loaded AO bake lands/commits** (the current
     committed dem has per-map bake hitches baked into its timing).
   - where the MP4 lives — too big for the repo; release asset, not committed.
   - extra idea: we can do the recording with and without our graphical improvements(flashlight, AO, and entity shadows) enabled, and then use ffmpeg to to a left/right split video, with original on the left and new on the right. 

3. **Later, optional:** engine-side `startmovie` frame-dump (method B) for a
   frame-perfect re-encode — only if the real-time grab quality disappoints.
   When it lands, only the capture step in script 2 swaps; the wrapper stays.

## Documentation

This comes last, when we are almost ready to release, and after we decided what insane things to implement.

our current ./docs/ folder is actually just research, and should be renamed and gitignored

- Readme, using similar style as our new unified menu
  - what this is not:
    - This is not a mod or a "remaster"
    - There is no modified or additional content or gameplay
  - This is:
    - a fork of the xash3d engine
    - a new unified controller-first menu UI, with a few more (existing) settings exposed; mostly just a new "theme"
    - a level streaming system (no more loading screens)
    - a new flashlight (optional, configurable)
    - supplemental ambient occlusion (optional)
    - a few additional quality-of-life settings, all optional and off-by-default
  - compatibility:
    - supported expansions/mods list is same as upstream xash3d-fwgs
    - existing xash3d-fwgs savegames should work (not thoroughly tested)
  - Readme.md is just primarily "getting started" and minimal explanation of what this project is. everything else belongs in separate pages that you link to from here. This keeps the core Readme clean and focused on introducing new users to the project, but they can find all the detailed documentation from there.
  - we aren't here to document the whole engine ourselves
  - of course, we _must_ document all the cvars that we added
  - include, near the top our AI attribution line: Created with assistance from Anthropic Fable 5, Opus 4.8, and Zennthic Elefant second-brain memory system
  - 


## TODO: put this in Elefant later (it was down 2026-06-14)

### Entity shadows softness — retuned 2026-06-14
James saw that the steep resolution-shrink (S/(1+soft*4)) gave blocky shadows
("pixelated, but the pixels themselves are soft") and chose "Gentler PCF (keep
occlusion)" over the AO-coverage and screen-space-blur alternatives.

Root cause: hardware 2x2 PCF penumbra = ~1 texel, so wide+smooth is impossible
(big texels = blocky-but-soft pixels; small texels = sharp). "Smooth" and "wide"
are mutually exclusive with bilinear PCF.

New softness ramp in gl_entshadow.c (R_EntityShadowsDepthPass): `S = S / soft`
for soft>=1 (soft1 = full-res bilinear / just anti-aliased, soft2/3/4 =
half/third/quarter res), floored at min(base, 192 = ES_SOFT_MIN_SIZE) so the map
stays high-res and the edge reads as a clean subtle soft ramp instead of
feathered blocks. softness 0 = full-res GL_NEAREST (hard). Built + installed.

If James wants a genuinely WIDE feathery penumbra later, that needs either:
- the deferred screen-space-blur project (no FBO/post-process infra in the engine
  yet; it would also serve the Stage 2 sun), or
- switching to AO-style projected soft coverage (loses per-pixel occlusion).

### Entity shadows: switched to AO-style soft coverage 2026-06-14 (SUPERSEDES above)
The bilinear-PCF softening above still read as blocky. James chose to drop the
shadow-map/occlusion and do it the AO way (and explicitly rejected the big-lift
screen-space approach as too much for a xash3d project).

Rewrote gl_entshadow.c: per caster CPU-rasterize the posed silhouette (new
R_StudioStampShadow in gl_studio.c) projected along the light dir, separable
box-blur it (real wide blur = softness cvar), upload, and project as a darkening
decal. Dropped the GPU depth map, the FB-corner render, and the pre-R_Clear pass
(removed R_EntityShadowsDepthPass). To avoid painting the ceiling, receivers are
gated to the shadowed side (projected-depth test vs caster centre).

cvars changed: r_entity_shadows_size is now the coverage-map res (default 128,
64..256); r_entity_shadows_softness is now a box-blur radius (default 4, 0..16).
Memory file entity-shadows.md is fully rewritten and current.

(See also memory file entity-shadows.md, which is up to date.)

