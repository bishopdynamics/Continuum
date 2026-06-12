# xash3d-streaming

Level streaming for Xash3D: play Half-Life 1 start to finish with zero loading screens.

**Goal achieved (2026-06-11): full retail HL1 campaign played through seamlessly —
no loading screens, no issues. Transitions are a single frozen frame (~21–25 ms)
with continuous music and sound.** Run it: `tools/play-hl1.sh`.

## Layout
- `xash3d-fwgs/` — clone of FWGS upstream engine (our base)
- `hlsdk-portable/` — clone of the portable HL game DLL SDK
- `docs/SYNTHESIS.md` — research synthesis + recommended architecture (start here)
- `docs/research/` — research phase findings (scope, engine internals, prior art, map data)
- `gamedata/` — local-only copyrighted HL assets for analysis (never distribute/commit)

## Status
- Research phase complete (2026-06-10): Phase 1 "resident campaign + atomic swap",
  Phase 2 local stitching. See docs/SYNTHESIS.md.
- M0 complete (2026-06-11): builds + instrumentation + baselines (docs/research/07).
- M1 complete: preprocessing tool `tools/hlstream_preprocess.py`, all 5 campaigns
  extracted + sanity-checked (docs/research/08, 09).
- M2 complete: in-memory transition state, `sv_transition_memstate` (docs/research/10).
- M3 complete: world residency cache, `mod_world_residency` — revisited maps restore
  in ~0.5 ms instead of reloading (docs/research/11).
- M4a complete: seamless transitions — no loading plaque (`cl_seamless_changelevel`),
  unthrottled handshake, drop-loop bugfix. Revisit transition = **~20 ms (~1 frame)**,
  frozen-frame cut, music continuous (docs/research/12).
- M4b complete: sound continuity — sounds on crossing entities (NPC speech, weapons,
  suit VOX) resume at their exact sample position after the swap
  (`sv_transition_sounds`, docs/research/13). Engine work is committed on the
  `streaming` branch of `xash3d-fwgs/`.
- M5 complete: whole-campaign preload — `world_preload` + generated
  `streampreload.cfg` warm the residency cache behind the menu (96 maps, ~1.8 s,
  ~490 MB). No transition ever loads a world from disk again (docs/research/14).
- Polish: resource-probe elimination (docs/research/15), map name overlay
  (`scr_drawmapname`), stuffcmds and drop-loop engine bugfixes (upstream candidates).
- **Validation complete: full HL1 campaign playthrough, seamless, zero issues
  (2026-06-11).** Next: expansions (Opposing Force, Blue Shift), They Hunger,
  Uplink; then Phase 2 local stitching evaluation (docs/SYNTHESIS.md).

## Build quickstart
See docs/research/07-m0-baseline-measurements.md "Build setup". Run:
`cd install && ./xash3d -windowed -game dayone` (demo data) — retail HL: drop your
Steam `valve/` folder into `install/` and run without `-game`.
