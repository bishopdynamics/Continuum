# Scope & Constraints

Decisions made 2026-06-10.

## Goal
Zero loading screens playing Half-Life 1 start to finish on Xash3D.

## Scope
- Singleplayer HL1 campaign first. Opposing Force / Blue Shift later — design must be
  extensible (no hardcoded HL1 map names in engine code; campaign data lives in
  generated/declarative metadata).
- Architecture (true seamless world vs invisible async transitions): decided after the
  research phase.
- Target: modern PC. RAM is effectively unlimited (whole-campaign residency is acceptable).

## Asset constraint (distribution)
We cannot distribute Half-Life's copyrighted assets. Users drop in their own copy.
Therefore:

1. **Original assets are never modified on disk.** All derived data goes to a separate
   writable cache/metadata directory. (Also keeps Steam file validation happy and makes
   uninstall/upgrade trivial.)
2. **Everything derived from HL assets is computed on the user's machine** — either at
   first launch (one-time preprocessing pass) or lazily at runtime. We do NOT ship
   precomputed patches derived from asset content: a shipped diff/patch that encodes map
   geometry or other asset data is arguably a derived work of the copyrighted assets.
   Shipping only *code that derives data locally* sidesteps that entirely.
3. What we ship: engine fork + preprocessing tool + small hand-authored config
   (e.g., known campaign quirk overrides, checksums to validate supported game versions).

### Expected first-launch / cached derivations
- Campaign map graph: parse every BSP's entity lump for trigger_changelevel /
  info_landmark / trigger_transition → directed graph with landmark names + positions.
- Global placement solve: chain pairwise landmark deltas over the graph (spanning tree),
  detect inconsistencies/overlaps where maps can't share one global space.
- Precache union tables (models/sounds across adjacent maps or whole campaign).
- Any pre-transformed geometry/collision data needed for stitching (translated submodel
  headers, namespaced "*N" submodel tables, etc.).
- Whatever else the chosen architecture needs — the preprocessing stage is the designated
  home for all expensive computation.

Since HL's assets are identical across installs (per Steam build), derivation is
deterministic; we can ship expected checksums to verify a user's install is a supported
version before preprocessing.
