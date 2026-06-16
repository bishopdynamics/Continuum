# Elefant-Offline

Local cache of memories to replay into Elefant once it's back. Elefant's embedder
returned `403 Forbidden` for every search/list/capture call (session 2026-06-16),
so nothing could be consulted or written there. Each entry below is a captured
memory: tag with project `xash3d-continuum` (aka legacy `xash-streaming`) when
replaying.

---

## 2026-06-16 — Flashlight horizontal + vertical offset

- The projected flashlight (`xash3d-fwgs/ref/gl/gl_flashlight.c`) now has TWO
  position offsets off the eye:
  - `r_flashlight_offset` (vertical): default changed `4` → `-8` (chest level);
    clamp widened `-20..20` → `-24..24`. `+` above (headlamp), `-` below (chest).
  - `r_flashlight_offset_h` (horizontal, NEW): default `0`, clamp `-24..24`.
    `+` right (shoulder), `-` left, `0` centered.
- Horizontal offset is applied along a WORLD-horizontal "right" vector
  (`RI.vright` with Z zeroed then renormalized) so a shoulder offset stays level
  and doesn't drift up/down with view pitch. Vertical stays pure world-Z. The
  fixed `-28` backward step along vforward is unchanged.
- Menu: Customize Flashlight sub-page (`3rdparty/mainui/menus/continuum/Config.cpp`,
  `CMenuContFlashlight`) gained a "Horizontal Offset" slider beside the updated
  "Vertical Offset" slider — both `-24..24`, step 2, defaults `0` / `-8` — and
  both are in the reset-to-default (`X` key) handler. Page is now 10 rows; layout
  ends ~y=744 within the 768 virtual height (tight but fits, not yet eyeballed).
- Verified: `tools/build-engine.sh` → `BUILD-AND-INSTALL-OK` (covers renderer + menu).

## 2026-06-16 — demo capture pipeline consolidated into capture-demo.sh

- CONFIRMED (James tested): a recorded demo does NOT capture the menu UI — mainui
  isn't part of the demo stream. So demo→capture is gameplay-only; the menu tour
  must stay a hand-driven screen grab.
- NEW `tools/capture-demo.sh [demo]`: one demo run → BOTH `dist/media/<demo>.mp4`
  (H.264/NVENC master) and `dist/media/<demo>.gif` (small, derived from the MP4 via
  2-pass palettegen/paletteuse). With NO arg it batch-captures every `demos/*.dem`.
  - Reuses the `startmovie` FIFO pipeline (glReadPixels, no screen grab → no tearing).
  - GIF is built from the finished MP4 (lossy source is imperceptible at GIF's
    downscaled fps/size, and avoids a huge lossless temp).
  - Idempotent: valid MP4 present → skip; only GIF missing → rebuild from MP4 (no
    re-capture); `FORCE=1` re-captures. Validate-by-size + retry (RETRIES, MIN_MB)
    guards the rare tiny-truncated-file failure.
  - Env: GAME/WIDTH/HEIGHT/FPS/FPS_CAP/VSYNC, ENCODER/CQ/NVENC_PRESET/CRF/PRESET,
    AUDIO/AUDIO_DEV/ABITRATE, GIF_FPS/GIF_WIDTH, MIN_MB/RETRIES/FORCE/OUTDIR.
- REPLACES (all removed): `capture-demo-video.sh`, `capture-all-demo-videos.sh`,
  `capture-gif-of-gameplay.sh`.
- `tools/capture-menu-gif.sh` KEPT (hand-driven x11grab; only thing that can grab
  the menu). Reworked to take an optional name and output `dist/media/<name>.gif`
  (default `menu-tour`) instead of writing `doc/media/` directly — so it matches the
  workflow: shoot candidates into dist/media/, hand-pick the best into
  doc/media/menu-tour.gif (still embedded by README.md and doc/menu.md).
- Gotcha hit + fixed: under `set -u`, `local a=$1 b="$a..."` errors ("a: unbound")
  because bash expands ALL of `local`'s args before assigning any — split into two
  `local` statements.
- Verified end-to-end on `demos/zombie_shadows.dem`: attempt 1 hit the tiny-file
  failure, auto-retried, attempt 2 produced MP4 (38M) + GIF; skip and
  rebuild-gif-only paths both verified. (zombie_shadows is long → ~27 MB GIF at
  480px; use short demos + lower GIF_FPS/GIF_WIDTH for README sizes.)
- SESSION_START.md now (James's edit) points here as the offline Elefant cache:
  replay these into Elefant when it's back, then delete the replayed entries.

## 2026-06-16 — Elefant embedder outage

- Elefant MCP unreachable this session: `search`, `memory_search`, `memory_list`,
  etc. all return HTTP 403 Forbidden from `http://embedder:8001`. Could not consult
  or write Elefant memories. (Transient infra issue — note for the replay, not a
  durable fact about the project.)
