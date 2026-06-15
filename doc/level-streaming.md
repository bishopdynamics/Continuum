# Level streaming

Continuum plays the Half-Life campaign — and every supported expansion — from
start to finish with **no loading screens**. Where the stock engine drops to a
loading plaque at each `changelevel`, Continuum keeps the world resident and
swaps maps in roughly a single frame.

## What you actually see

- **No loading plaque.** The last rendered frame stays on screen during the
  swap, so a transition reads as a brief (~20–25 ms) freeze rather than a black
  loading screen. Music and ambient sound continue without a gap.
- **Continuous audio.** Sounds playing on entities that cross the transition —
  NPC dialogue, the suit voice, a weapon firing — resume at their exact sample
  position on the other side.
- **Instant revisits.** Backtracking into a map you've already been to restores
  it from memory in well under a millisecond instead of reloading from disk.

Every HL1 transition area blocks line of sight into the next map by design, so
the invisible swap is perceptually seamless — you don't catch the engine in the
act.

## How it works (briefly)

The engine keeps parsed world models resident across changelevels
(`mod_world_residency`), holds transition state in memory instead of writing
`save/*.HL?` files to disk (`sv_transition_memstate`), and skips the loading
plaque (`cl_seamless_changelevel`). Behind the main menu it pre-warms the
residency cache for the whole campaign, so no transition ever has to load a
world from disk during play.

This works for **any** installed game or mod, not just retail Half-Life — the
engine scans the game's maps (loose files or pak archives), builds the
changelevel graph, and preloads it automatically. No external tooling or
per-game configuration is required.

## Tuning it

All of the relevant cvars are in the [cvar reference](cvars.md#level-streaming--transitions).
The defaults give you the full seamless experience; set them to `0` to move
back toward stock behaviour if you want to compare.
