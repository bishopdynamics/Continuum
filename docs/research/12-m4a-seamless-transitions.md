# M4a — Seamless Transitions: Plaque Removal + Blackout Profiling + Fixes

> 2026-06-11. Engine changes #3. The deep-profiling session that got revisit
> transitions from ~125 ms to ~20 ms (~1 frame).

## Changes

1. **`cl_seamless_changelevel` (default 1)** — engine/client/cl_scrn.c.
   On changelevel, skip the loading-plaque frame entirely: no `draw_changelevel`, no
   extra `SCR_UpdateScreen`. `cls.disable_screen` already makes `V_PreRender` skip all
   rendering, so the last presented frame simply stays on screen until the new level's
   first frame. 0 restores the stock plaque.
2. **Unthrottled transition handshake** — engine/common/host.c `Host_CalcFPS`.
   When `cls.disable_screen` is set, return fps=0 (no Autosleep pacing): rendering is
   frozen, so frame pacing only delayed the multi-leg signon handshake (each leg costs
   one host frame; they now run back-to-back in ~1 ms total).
3. **CL_ParseClientData drop-loop clamp** — engine/client/parse/cl_parse.c.
   The "mark dropped frames" loop iterated the full sequence gap; across a changelevel
   that gap is huge and the loop burned **35–56 ms** rewriting the same 64 frame-window
   slots. Clamped to `max(last+1, i - CL_UPDATE_MASK)` — semantically identical.
   **Upstream-worthy bugfix** (affects stock Xash too on any large sequence jump).

## Profiling method & findings (for posterity)

`[streamprof]` marks at every stage boundary + strace for syscall-level blocking:
- Client prep (R_NewMap lightmaps+VBO + sprites + sky) is only **~4 ms** — the renderer
  was never the problem on modern GPUs.
- The signon handshake legs are frame-paced (fix #2).
- svc_clientdata took 35–56 ms → the drop-loop (fix #3). svc_resourcelist ~6 ms (future
  target; resource list processing).
- A recurring exactly-16.7 ms stall traced (via strace: main thread poll on the display
  fd, 11–15 ms blocks at 60 Hz) to **NVIDIA's deferred vsync/vblank wait** bleeding into
  transition timing. With the plaque frame skipped and per-frame debug prints removed it
  lands before the transition window; both vsync on/off now measure the same.

## Results (retail HL1, c1a0↔c1a0d round trip, listen client, RTX 3060)

| Metric | Session start | After M2+M3 | After M4a |
|---|---|---|---|
| Revisit blackout (user-visible freeze) | ~125 ms | ~71 ms | **~20 ms (~1 frame)** |
| Revisit server-side total | ~25 ms | ~24 ms | **~9.5 ms** |
| First-visit blackout | ~125 ms | ~86 ms | **~45 ms** (world load 33 ms dominates → M5 preload makes every map a revisit) |

User experience now: transition = one frozen frame, no loading screen, music continues.
Ambient sound still cuts (S_StopAllSounds kept for restore correctness — M4b target).

## Remaining (M4b/M5)

- Sound continuity across the swap (skip stop, or stop+seamlessly resume loopers;
  needs entity-channel identity care).
- M5: warm the world-residency cache for the whole campaign at startup (every
  transition becomes a revisit ≈ 20 ms).
- svc_resourcelist ~6 ms; remaining server-side ~9 ms (save/restore loop) — optional.
- Real-gameplay validation: walk-through trigger transitions (not console-driven),
  backtracking with monsters, autosaves, full campaign run.
- Profiling marks (`[streamprof] mark ...`) are dev scaffolding — strip before any
  release builds; stage timings + blackout total are worth keeping behind a cvar.
