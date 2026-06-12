# Research Synthesis & Recommended Architecture

> 2026-06-10. Distills docs/research/00–06. Status: recommendation for James to approve.

## What the research established

1. **Nobody has done this.** No Xash3D fork, no Quake-family engine, not even Source 2
   does engine-side level streaming. All prior art is content-side (bspguy map merging,
   Sven Co-op chapter merges) or masking (Source/Alyx). We'd be first; there is no
   scaffolding to build on, but also no conflicting design to fight.

2. **A single global merged world is impossible.** Ground-truth extraction from all 96
   BSPs proves pairwise landmark alignment does not extend to one consistent space:
   major overlaps (Surface Tension, Forget About Freeman), duplicate-space maps
   (Unforeseen Consequences = damaged copies of Anomalous Materials at identical coords),
   parallel transitions with contradictory transforms (c2a5w↔c2a5x disagree by 16 units),
   and teleport edges with no spatial relationship (Xen). Any "seamless" design must be
   **local**: active map + neighbors placed per-pair, and some edges can only ever be
   masked swaps (teleports, elevators, scripted discontinuities like the capture sequence).

3. **The swap cost is artificial.** Today's changelevel stall = synchronous BSP load +
   disk round-trip of entity state + full server teardown + client reconnect + asset
   reload + deliberate loading plaque. None of these is fundamental: the whole campaign
   is ~147MB of BSPs (whole-campaign residency is trivial on target hardware), entity
   state can stay in memory, and the client/renderer can keep running if we don't tear
   them down.

4. **The maps themselves cooperate.** Adjacent maps duplicate the transition-region
   geometry (1998 mapper convention), every transition is bidirectional, vanilla already
   fakes vehicle continuity with per-map duplicate trains, and the trigger_changelevel/
   landmark/trigger_transition system is a static streaming graph authored into the maps.
   bspguy proved relative teleports (keep relative position/angles/velocity) are
   imperceptible when geometry matches.

5. **The engine fights us in specific, known places.** Single-world singletons
   (sv.worldmodel, areanodes, monolithic PVS, renderer WORLDMODEL/lightmap-atlas/VBO),
   spawncount-keyed client reinit, hlsdk edict-0/CWorld assumptions, "*N" submodel name
   collisions, 512-entity transition cap. All catalogued with file:line in docs/research.

## Recommended architecture: two phases, one mechanism

The key insight: **because some edges must be masked swaps no matter what, the atomic-swap
machinery is required in any design — so build it first and make it so fast it IS the
product; then add local stitching edge-by-edge as an enhancement.** Phase 1 is not
throwaway work for Phase 2; it is its foundation.

### Phase 1 — Resident campaign + atomic swap ("zero loading screens")
- **Preload everything at startup**: parse all campaign BSPs server-side into resident
  model pools; preload the client-side union of textures/sounds (WADs are heavily
  shared). First-launch preprocessing computes the map graph, precache unions, and quirk
  tables. Initial load can hide behind the menu and the tram-ride intro.
- **In-memory transition state**: replace the .HL1/.HL2 disk round-trip with an in-memory
  per-map state store (Quake 2 unit model — the format already exists, just don't touch
  disk).
- **In-place swap instead of teardown**: keep the client connected and the renderer
  alive; no spawncount bump / svc_serverdata / plaque / S_StopAllSounds; swap the world
  model and rebase entities by the landmark delta in one server frame, preserving the
  player's relative position, view angles, and velocity (bspguy relative-teleport
  semantics). Music and looping sounds continue; effects/decals near the boundary
  optionally carried.
- **Target: transition cost ≤ one frame.** With matched boundary geometry, the swap frame
  is visually near-continuous. This alone delivers the stated goal — HL1 start to finish
  with zero loading screens — for ALL 98 edges including teleports and elevators.

### Phase 2 — Local stitching for walk-through edges (true seamlessness)

> **VERDICT (2026-06-11, after full-campaign validation): NOT NEEDED for HL1-family
> content.** Valve designed every transition area to block line of sight into the
> next map (S-bend corridors, airlocks, elevators, track bends) — a GoldSrc-era
> necessity that makes the invisible atomic swap perceptually identical to true
> stitching. Empirical confirmation: a complete attentive playthrough on Phase 1
> noticed zero transitions. The remaining benefit (removing one already-imperceptible
> frozen frame) cannot justify the hardest engineering in this plan (dual coordinate
> spaces, PVS merging, the catalogued inconsistent-transform anomalies). Phase 2 is
> shelved unless future content (custom maps with open transition sightlines)
> motivates it. The section below is kept as the design record.
- For edges the preprocessing stage certifies as stitchable (no overlap conflict,
  consistent transform — the majority of corridor transitions): make the neighbor map
  resident in the active map's space as an offset SOLID_BSP sub-world, using the
  engine's existing brush-model collision (SV_ClipMoveToEntity) and brush-model render
  path (both verified to support external BSPs in principle). Neighbor entities dormant;
  crossing the boundary promotes the neighbor to active (an already-instant Phase 1 swap
  that the player cannot detect because both worlds are visible the whole time).
- This removes the last artifact — the single-frame pop and the "doorway only" view —
  enabling free back-and-forth walking and seeing into the next map.
- Per-edge opt-in driven by preprocessed metadata; un-stitchable edges keep Phase 1
  behavior. Overlap-region double-geometry (both maps render their copy of the shared
  corridor) needs a culling policy — catalogued per-pair offline.

### Out of scope until later
- Save/load compatibility polish, expansions (OF/BS), multiplayer (never), upstreaming.

## Open design questions for the next phase (ordered)
1. Engine-fork strategy: carry changes as a patch series on FWGS master (rebase-friendly)
   vs. hard fork. Lean: patch series + upstream-quality code, decide later.
2. How the hlsdk side participates: we control hlsdk-portable too — how much of the swap
   can live engine-side without breaking the game-DLL ABI for vanilla HL dlls?
   (We ship our own game dll build anyway — but keeping ABI sane keeps OF/BS cheap.)
3. Sound/music continuity details across the rebase (offset all active sound origins).
4. Monster AI state across swap (currently restored via save tables; in-memory store
   should preserve more than vanilla — e.g., squad state, schedules).
5. Whether client prediction needs special handling on the rebase frame (likely: shift
   predicted origins by the same delta).

## Suggested next milestones
1. **M0 — Build & baseline**: build xash3d-fwgs + hlsdk locally, run HL1, instrument and
   measure real changelevel costs per stage (we have the hooks catalogued).
2. **M1 — Preprocessing tool**: BSP entity-lump parser → map graph + landmark transforms
   + quirk table + stitchability report (we already have the ground-truth data to
   validate it against).
3. **M2 — In-memory transition state** (kill the disk round-trip) — small, isolated win.
4. **M3 — Resident world models** (don't free on changelevel; load-once policy).
5. **M4 — The atomic swap** (no teardown/reconnect/plaque) — the heart of Phase 1.
6. **M5 — Asset preload union** (client textures/sounds) → measure: is the swap ≤1 frame?
7. ~~Then evaluate Phase 2 stitching with real numbers in hand.~~ Evaluated:
   shelved — transition areas block all sightlines by design, Phase 1 is
   perceptually complete (see Phase 2 verdict above).
