# Prior Art & How Other Engines Handle It

> Web research findings, 2026-06-10. Adversarially verified where noted.

## 1. The headline: nobody has done engine-side streaming for GoldSrc/Xash3D

Verified across FWGS upstream, w23/xash3d-fwgs (Vulkan/RT), sultim-t/xash-rt (HL1 RTX),
PrimeXT, and DarkPlaces: **no fork or related engine has async/background map loading,
multi-BSP residency, or seamless changelevel work.** No FWGS issue/PR even proposes it.
Every prior "seamless HL" effort is content-side, not engine-side. We would be first.

Even Source 2 / HL:Alyx does NOT stream: it masks loads with flat-shaded copies of
adjacent areas and loads the next map over the current one. Valve's stated position: real
streaming "would require building a new engine."

## 2. Content-side prior art (the useful stuff)

### bspguy (wootguy) — github.com/wootguy/bspguy
The most concrete reusable technique in the ecosystem. Merges multiple GoldSrc BSPs into
one BSP, placing sections APART in world space (sidestepping geometric overlap), with:
- **Relative teleports** for transitions: trigger_teleport with Relative + Keep Angles +
  Keep Velocity flags between geometrically identical duplicated corridor sections.
  Player's relative position/velocity preserved → imperceptible teleport.
- Generated entity logic (`bspguy_mapchange`/`bspguy_mapload`) activates/deactivates each
  section's entities — entity-level streaming faked inside one BSP.
- Known ceilings: MAX_MAP_CLIPNODES (32767) is hit first; all sections' entities simulate
  at once (server perf).
- Wiki: github.com/wootguy/bspguy/wiki/Seamless-Transitions-in-Merged-Maps

### Sven Co-op
Ships the whole HL1 campaign with maps **merged per chapter** (hl_c00 = all 6 Black Mesa
Inbound maps) — rebuilt from decompiles in Hammer on their raised-limits "Svengine".
Proves chapter-scale merging is geometrically feasible; transitions between chapters remain.

### HalfMapper (gzalo) — github.com/gzalo/HalfMapper
Renders ALL HL1 maps simultaneously aligned by info_landmark origins. Its
`docs/overlaps.md` + per-map manual offset config is a ready-made catalogue of where
HL1's stitched world self-intersects (see doc 06). Visualization only.

### Others
- w23/OpenSource: Source-map world stitching via landmark patching (author = the Xash
  Vulkan renderer dev — relevant contact/precedent).
- GMod INFMAP "Black Mesa Full": whole HL1 facility hand-stitched in Blender as one model
  (visual only). Confirms the world fits one coherent space after manual overlap fixes.
- "Half-Life: In One Map" (VDC): HL:Source, vaporware, nothing reusable.
- 2011 ModDB thread "Seamless Half-Life": idea-only; correctly identified overlap problem.

## 3. Engine-family survey

| Engine | Finding |
|---|---|
| FTEQW | Closest thing to multi-BSP: external .bsp set as a SOLID_BSP **entity** gets full BSP collision; its entities are NOT spawned (QC must respawn them, offset by parent origin); it never participates in worldmodel PVS/lighting. Also: MenuQC persists across map changes (persistent transition UI precedent); map-cluster subservers = sharding, not seamless. |
| DarkPlaces, Ironwail, vkQuake, QSS | No async/threaded map load anywhere. QSS/Ironwail decoupled renderer from server tick — a useful prerequisite pattern. |
| Hexen II hubs / Quake 2 units | Visible loads, but **persistence decoupled from residency**: per-map entity-state files in the save dir, reloaded on revisit. Architecturally identical to HL's .HL1 files. |
| Metroid Prime | The canonical door-streaming design: **max two rooms resident** (current + the one being entered); door's force field won't open until neighbor finishes loading; only one neighbor preloaded at a time in multi-door rooms; elevators do full unloads to defeat heap fragmentation. (Sources: Jack Mathews interviews, MREA format docs, PrimeDecomp.) |
| OpenMW | Proven streaming retrofit onto a cell engine: background-thread preloading triggered by door-approach distance / cell-border proximity. |
| Source 1/2 | Masked blocking loads + trigger_transition entity carry + duplicated boundary geometry. No co-residency ever. |

## 4. Transferable design lessons

1. **Adjacent HL1 maps already duplicate the transition-region geometry** (mapper
   convention since 1998) — the visual continuity asset for any swap-based approach.
2. **bspguy's relative-teleport trick** = how to make an instantaneous coordinate rebase
   imperceptible (preserve relative position, view angles, velocity).
3. **Metroid model**: current + preloading neighbor, gate crossing on load completion,
   periodic full unload. OpenMW: trigger preload by approach distance.
4. **Quake 2 unit model**: always-on per-map entity-state cache decoupled from residency
   (HL's .HL1 transition files are already 90% of this).
5. **QSS/Ironwail**: decouple renderer from simulation before attempting async anything.
6. Nobody in the family does true dual-world PVS/collision — if we do full co-residency,
   we are off the map (the FTEQW BSP-as-entity hack is the only partial precedent, and it
   matches the mechanism Xash already uses for func_door/trains).
