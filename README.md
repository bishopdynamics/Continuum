# xash3d-streaming

Level streaming for Xash3D: play Half-Life 1 start to finish with zero loading screens.

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

## Build quickstart
See docs/research/07-m0-baseline-measurements.md "Build setup". Run:
`cd install && ./xash3d -windowed -game dayone` (demo data) — retail HL: drop your
Steam `valve/` folder into `install/` and run without `-game`.
