# M2 — In-Memory Transition State

> 2026-06-11. Engine change #1. Diff: ~300 lines, all in engine/server/sv_save.c
> (+cvar registration in sv_main.c/server.h).

## What changed

Level-transition state (`save/<map>.HL1/.HL2/.HL3` — server entities, client state,
entity patches) no longer round-trips through disk on every changelevel. A memory layer
(`msentry_t` list + `savefile_t` handle) sits behind all save/restore I/O in sv_save.c:

- `SaveFile_Open/Read/Write/Close/Length` — drop-in for the FS calls; writes to
  transition files go to memory when `sv_transition_memstate` (default 1) is on; reads
  prefer a memory entry and fall back to disk; everything else passes through to FS.
- Explicit savegames keep working: `DirectoryCount`/`DirectoryCopy` bundle memory
  entries into the `.sav` (memory wins over stale disk copies), `DirectoryExtract`
  repopulates memory from a loaded `.sav`, `ClearSaveDir` clears both.
- `sv_transition_memstate 0` restores byte-identical legacy disk behavior.

## Verification (all passed)

1. **Round trip** c1a0 → c1a0d → c1a0: state written/restored from memory on both hops
   (`Loading game from save/c1a0.HL1` succeeds with no disk file present);
   zero `.HL?` files on disk after the run.
2. **Save/load cycle**: `save memtest` bundled memory entries into a valid 171KB .sav;
   `load memtest` extracted into memory and restored.
3. **Legacy regression**: with cvar 0, `.HL1/.HL2/.HL3` appear on disk again.
4. **Real-world compat**: James's actual 2017 Steam/GoldSrc save (`Half-Life-000.sav`)
   loads through the new extract path; gameplay + an organic tram changelevel followed.

## Timing impact

Modest as predicted (disk was warm-cache): c1a0↔c1a0d hops ~43 ms server-side.
The point of M2 is architectural: transition state is now an in-memory object with a
single owner, which M4's atomic swap can consume directly — and the .sav format remains
the only on-disk persistence, used only when the user explicitly saves.

## Notes / future

- Engine writes saves to `valve/SAVE/` (pre-existing dir from retail copy is reused).
- The memory layer is engine-side only; the game DLL is untouched.
- M4 follow-up: skip serialization entirely for the common case (entities that stay in
  their map) — the save-table path then only handles cross-boundary entities.
