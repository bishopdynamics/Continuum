# M1 — Preprocessing Tool (prototype)

> 2026-06-11. `tools/hlstream_preprocess.py` → `cache/mapgraph-{hl1,of,bs}.json`

## What it does
Parses GoldSrc BSPs (v30, including the Blue Shift lump-swapped variant) directly from
the user's install and derives: per-map metadata (size, entity count, world bounds,
landmarks, trigger_transition volumes), the undirected transition graph with per-landmark
rigid transforms (b_to_a_offset), USE-only flags, stitch-candidate classification
(consistent transform + walk-through), and an anomaly report. Ships as code; all derived
data is computed locally per the asset constraint.

## Validation (HL1, retail Steam maps)
Matches the research ground truth exactly: 96 maps, 222 triggers, 98 edges; all 14 hubs
(c1a3, c1a4b at degree 4); all 3 missing-landmark quirks (c1a0btoc, a1a1b, c3a2_fc);
all 6 inconsistent-parallel-transform pairs incl. c2a5w↔c2a5x's 16-unit Y disagreement.

## Campaign stats

| Campaign | Maps | Edges | Stitch candidates | USE-only | Hubs (deg≥3) | Anomalies |
|---|---|---|---|---|---|---|
| Half-Life (c*) | 96 | 98 | 85 (87%) | 5 | 14 | 9 |
| Opposing Force | 68* | 41 | 29 | 12 | of3a1, of4a4 | 0 |
| Blue Shift | 37* | 35 | 32 | 3 | 4 | 2 |

*includes multiplayer maps as isolated nodes (no campaign-name filter yet for expansions).

Notes: Gearbox's data is much tidier than Valve's (zero anomalies). Blue Shift BSPs swap
the entities/planes lumps — detected by content sniffing (`classname` probe), the same
trick the engine uses. Expansions confirmed structurally identical (trigger_changelevel +
info_landmark), so the streaming design carries over unchanged.

## TODO (production version)
- Geometry-level overlap analysis per edge (bbox-level first) to refine stitch_candidate
  into stitchable-certified (cross-check vs HalfMapper overlaps.md).
- Campaign filters per game (of*/ba_* name sets, or walk the graph from startmap).
- Quirks override table (hand-authored) merged into output (e.g., c1a0btoc → c1a0etoc).
- Precache union computation (models/sounds per neighborhood / whole campaign).
- Emit into the engine-consumed cache format once that's designed (M4).
