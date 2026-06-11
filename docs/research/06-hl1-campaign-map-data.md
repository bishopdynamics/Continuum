# HL1 Campaign Map Data (Ground Truth)

> Extracted 2026-06-10 by parsing entity lumps + worldspawn bboxes of all 96 retail
> Steam-era campaign BSPs (local corpus: gamedata/maps/, NOT distributable).
> Items marked [BSP] are parsed from map data; [SDK] verified in hlsdk source.

## 1. Shape of the campaign

- **96 maps, 222 trigger_changelevel entities, 98 undirected map-pair edges.** [BSP]
- **Every edge is bidirectional at the entity level** — zero asymmetric transitions;
  Valve always placed return triggers, even "unreachable" ones (c4a3→c4a1f). [BSP]
- Hubs with 4 distinct neighbors: **c1a3** (We've Got Hostiles loop) and **c1a4b**
  (Blast Pit silo — with THREE separate transitions to c1a4i at different silo levels).
  Twelve more maps have 3 neighbors (incl. c3a2c Lambda Core hub: 7 triggers, 3 neighbors,
  mixing walk routes and teleporters). [BSP]
- Real backtracking: Blast Pit silo loop, We've Got Hostiles loop, On A Rail (train
  rideable both directions, optional branches c2a2b2/c2a2h), Lambda Core teleporter labs.
- Full adjacency list captured in the research transcript; regenerate any time by parsing
  trigger_changelevel/info_landmark from gamedata/maps (preprocessing tool will own this).

## 2. Sizes (streaming budget) [BSP]

- Total campaign: **~147 MiB across 96 BSPs**, mean ~1.6 MB, max 3.54 MB (c1a1f).
- Entity counts: 67 (c1a1d) to 719 (c2a5f); all < 1024 (MAX_MAP_ENTITIES).
- A chapter (8–10 maps) = 10–17 MB. **Whole-campaign residency is trivially affordable
  on a modern PC** — even fully parsed in-engine representations (~5–10x file size) fit
  in a couple of GB.

## 3. Geometric overlap: a single global merged world is IMPOSSIBLE

Evidence that pairwise landmark alignment does NOT extend to one consistent global space:

1. **HalfMapper overlaps.md**: overlap in Black Mesa Inbound (c0a0b×c0a0c), minor in
   Blast Pit & Power Up, **MAJOR in Surface Tension and Forget About Freeman**;
   Apprehension's trash compactor un-placeable; c1a1b needed manual (0,-96,0) correction.
2. **Duplicate-space maps** [BSP]: Unforeseen Consequences maps are damaged COPIES of
   Anomalous Materials spaces at identical coordinates (c1a0c≈c1a0b, c1a1≈c1a0a,
   c1a1a≈c1a0d — identical landmark origins). Alternate states of one space; must never
   be co-resident/co-rendered.
3. **Inconsistent parallel transitions** [BSP] — same map pair, different implied rigid
   transforms (cannot satisfy both): c1a1c↔c1a1d (~(86,1714,0) disagreement), c1a2b↔c1a2c
   (vents vs freezer: (750,949,62)), c1a4d↔c1a4e, and c2a5w↔c2a5x's two pipes disagree by
   exactly 16 units in Y (a genuine Valve landmark misplacement).
4. **Non-Euclidean teleport edges** [BSP]: Lambda Core c3a2b↔c3a2c has two different
   implied placements (walk route vs teleport); c3a2c↔c3a2f similar; Xen edges are
   teleports with no spatial relationship at all.
5. **27 adjacent pairs share an identical coordinate frame (zero landmark offset)** —
   i.e., they occupy literally the same coordinates and maximally collide if co-loaded
   naively (incl. c1a4b×c1a4i, c3a2c×c3a2d/f). [BSP, bbox-level]
6. Speedrunners exploit overlapping spaces ("Triggerdelay" technique) — vanilla maps
   overlap even between non-adjacent chapters.

**Design consequence:** placement must be **per-pair and local** (active map + its
neighbors positioned relative to the active map), with overlap conflicts catalogued by
the preprocessing stage. Some edges (teleports, USE-only discontinuities) can never be
spatially stitched and must always be masked swaps.

## 4. Vanilla map-data anomalies the preprocessor must handle [BSP]

- Missing landmarks referenced by triggers: c1a0b→c1a0c references `c1a0btoc` (target map
  only has `c1a0etoc` at the identical origin — naming slip); c3a1→c3a1b references
  `a1a1b` (absent); c3a2c→c3a2d uses landmark `c3a2_fc` that exists only in c3a2f.
  → need a hand-authored quirks/override table (ships with us; contains no asset data).
- USE-only transitions (spawnflag 2, fired by scripts not touch): tram/elevator/teleport
  edges incl. c2a3d↔c2a3e (capture sequence — deliberate (-4052,1936,-1700) discontinuity),
  c3a1 elevators, c3a2d→c4a1 (Xen teleport), all Xen portals.
- Two trigger_changelevels within ~56 units permanently disable level changes (engine
  quirk, TWHL-documented) — relevant if we synthesize trigger volumes.

## 5. Vehicles & special transitions [SDK]

- **func_tracktrain strips FCAP_ACROSS_TRANSITION** (trains.h:104): the tram/train is
  NEVER carried across — each map has its own pre-placed copy at the matching position;
  only the player moves; OverrideReset() re-attaches the train to its path on load.
  Vanilla already fakes vehicle continuity with per-map duplicates — our swap can too.
- Entity carry: landmark-PVS + FCAP_ACROSS_TRANSITION (or globalname), screened by
  trigger_transition volumes, **hard cap 512 entities** (MAX_ENTITY in CChangeLevel::
  ChangeList, with an overflow bug: bounds check fires AFTER an OOB write). Doors, plats,
  trains, buttons, tanks strip the carry flag.
- Known vanilla transition bugs (ValveSoftware/halflife issues #337/#338/#1572/#1942,
  #3313): players frozen/black screen, projectiles not carried, globalname crash —
  baseline behavior to not regress (or to fix).
