# Expansions Pass — OF / Blue Shift / They Hunger / Uplink

> 2026-06-11. The streaming stack applied to all remaining supported campaigns.
> No engine changes needed — the machinery is content-agnostic, as the M1
> sanity checks predicted.

## What was done per game

- `streampreload.cfg` generated into each game dir from the existing map
  graphs (`hlstream_preprocess.py` learned to take a mapgraph `.json` as input
  — needed for Uplink, whose maps live inside `pak0.PAK` and can't be globbed).
- `autoexec.cfg` created in each game dir with the preload hook.
- Launchers: `tools/play-opfor.sh`, `play-bshift.sh`, `play-hunger.sh`,
  `play-uplink.sh` (mirror `play-hl1.sh`; pass-through args, `-game` set).

## Validation (scripted round trip on a walkthrough edge, `-dev 2`)

| Campaign | Maps preloaded | Edge tested | Blackouts (ms) |
|---|---|---|---|
| Opposing Force (gearbox) | 43 | of1a1↔of1a2 | 56–79 |
| Blue Shift (bshift) | 37 | ba_canal1↔ba_canal1b | 32–48 |
| They Hunger (hunger) | 58 | they1↔they2 | 38–40 |
| Uplink | 10 | hldemo2↔hldemo3 | 45–48 |

All preloads complete, every transition restored its world from the residency
cache, transition sounds captured, no errors. Blue Shift's lump-swapped BSPs
load fine (engine-native support). They Hunger's 58 connected maps exclude 5
edge-less maps from its 63 — those cold-load gracefully if ever visited.

## Notes

- **Uplink gotcha (found by James at play time)**: the Uplink demo shipped as a
  renamed `valve/` dir, and its 1999 `liblist.gam` is the generic retail one —
  `game "Half-Life"`, **no `startmap`** — so New Game fell back to `c0a0` from
  the base valve hierarchy and played like retail HL ("looks like Day One").
  The pak itself was never the problem (`pak0.PAK` mounts fine, uppercase and
  all). Fix: hand-author `install/uplink/liblist.gam` like the dayone one —
  `game "Half-Life: Uplink"`, `startmap "hldemo1"`, `trainmap "t0a0"`.
  Verified: `newgame` spawns hldemo1. gearbox/bshift/hunger liblists were
  already correct (`of0a0`, `ba_tram1`, `thintro`).

- These numbers are **first-visit** transitions on entity-heavy maps (OF
  especially) — the cost is game-DLL entity spawn + studio/sound precache, not
  world loading. HL1 revisits measure 21–25 ms; backtracking in the expansions
  will be similarly fast. If the heavier first visits are perceptible in play,
  the next lever is precache warming (load every campaign model/sound at
  startup like the worlds).
- They Hunger's known content quirks (they1→they2 `onroad`/`onrail` landmarks
  missing in target, they19↔they20 inconsistent transforms) are mod bugs that
  behave exactly as in stock GoldSrc — preserved, not ours to fix.
- Per-game `streampreload.cfg`/`autoexec.cfg` live in `install/<game>/` —
  runtime-generated from the user's own data, correctly outside version
  control.
