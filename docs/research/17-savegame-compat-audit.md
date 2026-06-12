# Savegame Compatibility Audit

> 2026-06-12. Question from Notes.md: "did we break savegame compatibility with
> any of our changes?" Answer: **no**. Full diff review of every save-touching
> change on the `streaming` branch vs the upstream fork point (b2a5f0db).

## What was audited

`git diff b2a5f0db..streaming` over `engine/server/` and `engine/common/`, plus
the game DLL. Save-relevant files: `sv_save.c` (+416/-88), `sv_init.c`,
`sv_main.c`/`server.h` (cvar registration only). Every hunk in `sv_save.c`
falls into one of four buckets:

1. **I/O wrapper swaps** — `FS_Open/Read/Write/Close` → `SaveFile_*`
   (the M2 memory layer). Identical bytes, different destination: transition
   files (`save/<map>.HL1/.HL2/.HL3`) live in RAM instead of disk while
   `sv_transition_memstate 1` (default). `0` restores byte-identical legacy
   disk behavior (verified in M2).
2. **Directory bundling** — `DirectoryCount/Copy/Extract` learned to bundle
   memory entries into the `.sav` and extract back. The directory entry layout
   is exactly stock: `szName[MAX_OSPATH] + int fileSize + data`. Memory entries
   take priority over stale disk copies.
3. **Sound continuity (M4b)** — sounds captured at changelevel and restored on
   crossing entities. Uses the **pre-existing** SOUNDLIST field table
   (`gSoundEntry` via `pfnSaveWriteFields/ReadFields`) — same serialized
   layout; only *when* sounds are captured and *which* are restored changed.
   Both behaviors are gated behind `sv_transition_sounds` AND
   `host_level_streaming`; with either off, capture/restore is stock.
4. **Profiling** — `STREAMPROF` timing lines, runtime only.

**Not changed anywhere**: `SAVEGAME_VERSION`, `GAME_HEADER`/`SAVE_HEADER`
structs, the ETABLE dump, entity serialization (the full game-DLL
save/restore still runs on every transition — the "skip serialization for
non-crossing entities" idea from M2's notes was never implemented), entity
patches (`.HL3`), the symbol/hash table format.

**Game DLL**: `hlsdk-portable` is a clean checkout of upstream `master` with
zero local commits — entity save fields are vanilla.

Other engine diffs (residency cache in `model.c`, preload in `host.c`,
resource-probe skip in `sv_init.c`, menu/unified-config/OSK work) never touch
serialized state.

## Compatibility matrix

| Direction | Status | Evidence |
| --- | --- | --- |
| GoldSrc/Steam save → our engine | works | James's 2017 retail `Half-Life-000.sav` loaded + played through a changelevel (M2 verification #4) |
| Stock-xash save → our engine | works | same code path as above; format unchanged |
| Our save → our engine | works | continuous use; v1.6 UI testing created/overwrote/loaded/deleted saves; Jun 11 playthrough saves load today |
| Our save → stock xash3d-fwgs | works (analysis) | identical format; see note below |
| streaming on ↔ off (same engine) | works | `.sav` is the only persistence either way; extract goes to memory or disk per cvar; memory wins over stale disk files |
| Any xash save → GoldSrc | not supported | unchanged from upstream — xash reads GoldSrc saves, never the reverse |

### The one semantic delta

A `.sav` written mid-campaign with streaming on bundles changelevel `.HL2`
client-state blocks whose SOUNDLIST has `soundCount > 0` (stock leaves these
empty at changelevel — it only captured sounds for explicit saves). A stock
engine loading such a save parses those entries with the same field table
(format-valid) and then skips them via its `if( adjacent ) continue` rule —
i.e. crossing sounds simply don't resume, which *is* stock behavior. The
current level's own sound block is written by the explicit-save path, which we
left stock. Graceful in both directions.

## Verdict

No format changes, no version changes, no game-DLL changes. Transition state
moved from disk to RAM behind the same serialization, and the only new
payload (transition sounds) rides an existing, stock-parseable block that
stock engines deliberately ignore. Compatibility holds in every direction
upstream supported.

Untested empirically (low risk, analysis-only): loading one of our streamed
saves on a vanilla upstream build. Worth a one-off check before public
distribution, alongside the upstreaming work.
