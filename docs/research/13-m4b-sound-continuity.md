# M4b — Sound Continuity Across Transitions

> 2026-06-11. Engine changes #4 (commit c831e572 on `streaming`). Sounds now
> travel with the entities that cross a level transition and resume at their
> exact sample position after the ~1-frame swap.

## The discovery

The engine already had everything: `S_GetCurrentDynamicSounds` captures playing
channels *including sample positions*, `svc_restoresound` + `S_RestoreSound`
resume them client-side, and `RestoreSound` (server) maps entity numbers
through the save system's ENTITYTABLE — the exact mechanism that solves edict
renumbering across transitions. It was all wired for full saves only;
changelevel was explicitly skipped with the comment "sounds won't going across
transition".

## Why it could never have worked (two latent bugs)

1. **Capture ordering**: `Host_RunFrame` begins the loading plaque (which calls
   `S_StopAllSounds`) at the end of frame N; `SV_ExecChangeLevel` →
   `SaveGameState` runs in frame N+1. By capture time the channels are always
   empty. Even enabling the capture on changelevel yields zero sounds.
2. **Dead gate (also affected M4a)**: `cls.changelevel` is only set when the
   client parses `svc_changing` — which the server sends *inside*
   `SV_ChangeLevel`, after the plaque already ran. Any plaque-time logic gated
   on `cls.changelevel` (including M4a's seamless skip) never fired on the
   first plaque of a transition.

## Changes

1. **`S_CaptureTransitionSounds` / `S_GetTransitionSounds`** (s_main.c) —
   snapshot the dynamic channels at plaque time, before `S_StopAllSounds`;
   `SaveClientState` consumes the snapshot on changelevel (full saves keep
   using the live query).
2. **Changelevel detection at plaque time** (cl_scrn.c) — use
   `GameState->nextstate == STATE_CHANGELEVEL` (host state machine) instead of
   `cls.changelevel`. Fixes both the capture call and the M4a seamless gate.
3. **Adjacent sound restore** (sv_save.c `LoadClientState`) — on the
   adjacent-level pass, restore sounds whose entity maps to a valid edict in
   the transition table (= it crossed), translating origins by
   `vecLandmarkOffset` exactly like decals. Non-crossing entities' sounds are
   dropped (you left them behind).
4. **No stale replay** — sounds captured at a changelevel travel with the
   player; they are *not* restored from a map's own .HL2 on a later revisit
   (that path only restores sounds for full save loads, as stock).
5. **Music capture stays full-save-only** — music already continues naturally
   across transitions; capturing it would restart a stale track on revisits.
6. Cvar **`sv_transition_sounds`** (default 1), 0 = legacy stop-and-silence.

What still hard-cuts: static looped ambients (engine convention: the game DLL
restores those itself via entity restore — they restart at loop phase 0, which
is inaudible for hums; the new map's own ambients start on spawn as always).

## Verification (retail HL1, c1a0d↔c1a0 round trip via changelevel2)

- First visit: 4 sounds captured (test wav on player, weapon fire, two HEV VOX
  sentences), all 4 restored at exact positions (e.g. `!334 pos 16249`).
  A hivehand hornet projectile (ent 207) and a scientist's pain grunt (ent 7)
  also crossed and resumed in a separate run.
- Revisit back: 5 captured, only the 2 player-attached ones restored (gate
  correctly drops non-crossing entities). World from residency cache,
  **server 11.1 ms / blackout 21.3 ms** — M4a numbers hold with sounds on.
- Regression: fresh `save`/`load` cycle OK; James's 2017 GoldSrc retail save
  loads and the c0a0d tram ride crossed **two real trigger_changelevel
  transitions unattended** (c0a0d→c0a0e→c1a0 boundary) — first real-gameplay
  (non-console) validation of the whole stack.

## Test pattern notes

- Smooth transitions from console = `changelevel2 <map> <landmark>`
  (`changelevel` with 2 args is NOT the landmark form). Landmark names are in
  `cache/mapgraph-*.json`.
- `play <file.wav>` plays on the listener entity (crosses transitions);
  `spk` is for sentences only.
- Dev-only timings/diagnostics print with `-dev 2` (`[streamprof]` lines:
  `captured N dynamic sounds`, `transition sound: ...`).

## Remaining

- M5: whole-campaign preload (walk mapgraph warming the M3 cache; every
  transition becomes a ~20 ms revisit).
- Optional polish: svc_resourcelist ~6 ms, server-side save/restore loop ~9 ms.
- Real-gameplay validation pass: full campaign playthrough, backtracking with
  monsters, autosaves.
