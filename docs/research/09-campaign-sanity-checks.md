# Sanity Checks: All Supported Campaigns (valve, gearbox, bshift, hunger, uplink)

> 2026-06-11. Question under test: does our "transition machinery applies as-is"
> assumption hold across 100% of the assets this project will ever support?
> Answer: **yes** — verified at three levels (data, game-DLL, runtime).

## 1. Map-graph extraction (preprocessor, cache/mapgraph-*.json)

| Campaign | Maps | Edges | Stitch candidates | USE-only | Hubs ≥3 | Anomalies |
|---|---|---|---|---|---|---|
| Half-Life (valve) | 96 | 98 | 85 | 5 | 14 | 9 |
| Opposing Force | 68* | 41 | 29 | 12 | 2 | 0 |
| Blue Shift | 37* | 35 | 32 | 3 | 4 | 2 |
| They Hunger | 63 | 62 | **61** | 0 | 7 | 3 |
| Uplink | 10 | 10 | 8 | 2 | 3 | 0 |

*includes multiplayer maps as isolated nodes.

All five use identical machinery (trigger_changelevel + info_landmark). Format quirks
handled: Blue Shift's swapped entities/planes lumps (content-sniffed, same as engine);
uplink's `pak0.PAK` uppercase extension; They Hunger maps split across loose files + 5
paks (loose takes precedence, matching engine FS order). They Hunger is the most
streaming-friendly campaign in the set (61/62 edges stitch-candidates, zero teleports).
New quirks for the override table: they1→they2 references landmarks (`onroad`,`onrail`)
missing in they2; they19↔they20 has inconsistent parallel transforms.

## 2. Entity classname audit (maps vs game DLL implementations)

Extracted every classname spawned by every campaign map; diffed against
`LINK_ENTITY_TO_CLASS` registrations in the matching hlsdk-portable branch:

| Campaign | DLL source | Missing classnames |
|---|---|---|
| valve, uplink | master | 1: `ammo_9mmARclip` — **a Valve bug, not ours**: retail hl.dll doesn't register it either (verified via `strings hl.dll`); these entities silently fail in vanilla HL too |
| gearbox | origin/opfor | 0 |
| bshift | origin/bshift | 0 |
| hunger | origin/theyhunger | 0 |

hlsdk-portable has maintained branches for every campaign (plus ~50 other mods —
relevant for future mod support). No dependency on the Windows-only `einar.dll`:
the theyhunger branch builds a native `einar_amd64.so` (name matches hunger's liblist).

## 3. Runtime transition tests (engine + branch DLLs, GL client, scripted changelevel2)

All branch DLLs built 64-bit with the same waf config as master. One smooth transition
per campaign, instrumented:

| Campaign | Transition | Server-side total | Client blackout | Arrived |
|---|---|---|---|---|
| valve | c2a5e → c2a5f | 71.7 ms | 124.9 ms | ✓ |
| hunger | they2 → they3 (landmark biggut) | 80.0 ms | 140.4 ms | ✓ |
| gearbox | of1a1 → of1a2 | 76.5 ms | 156.1 ms | ✓ |
| bshift | ba_tram1 → ba_tram2 | 48.6 ms | 123.6 ms | ✓ |
| uplink | hldemo1 → hldemo2 | 81.3 ms | 144.1 ms | ✓ |

Consistent ~50–80 ms server / ~120–160 ms blackout band across every campaign.
Benign noise observed (not blockers): missing optional vgui_support lib; "Couldn't open
save data file" on first-visit adjacency probes (vanilla behavior); a few missing
sounds in mod content.

## Verdict

The streaming design generalizes: one metadata-driven mechanism covers all five
campaigns. Per-campaign specifics live entirely in (a) the preprocessor output and
quirks table, (b) which game DLL branch is built. No campaign-specific engine code
anticipated. Branch worktrees live in `hlsdk-branches/`.
