# Changelevel / Level Transition System (engine + hlsdk)

> Code-dive findings, 2026-06-10. Repos: xash3d-fwgs + hlsdk-portable.
> Line numbers approximate; re-verify before patching.

## 1. Two transition modes

- **Smooth** (`changelevel2 map landmark`, singleplayer): save/restore entities with
  landmark-based coordinate remapping. Disabled for maxclients > 1.
- **Classic** (`changelevel map`): discard everything, fresh spawn, `pfnResetGlobalState`.

## 2. Full call sequence (trigger touch → player in new map)

```
CChangeLevel::TouchChangeLevel            hlsdk dlls/triggers.cpp:~1505
└─ ChangeLevelNow                          triggers.cpp:~1443
   ├─ InTransitionVolume(player, landmark) triggers.cpp:~1540  (trigger_transition volumes)
   ├─ FindLandmark → gpGlobals->vecLandmarkOffset = landmark origin
   └─ CHANGE_LEVEL(map, landmark)          → engine pfnChangeLevel

SV_QueueChangeLevel                        engine/server/sv_game.c:~713
└─ COM_ChangeLevel → GameState.nextstate = STATE_CHANGELEVEL   common/host_state.c:~109
Host_RunFrame: SCR_BeginLoadingPlaque + Host_SetState(STATE_CHANGELEVEL)
COM_Frame → SV_ExecChangeLevel → SV_ChangeLevel                engine/server/sv_save.c:~2036

SV_ChangeLevel(smooth path):
  1. pSaveData = SaveGameState(true)       sv_save.c:~1458
     ├─ pfnParmsChangeLevel → BuildChangeList (triggers.cpp:~1535) — adjacency LEVELLIST
     ├─ pfnSave per entity → ENTITYTABLE
     └─ write save/<map>.HL1 (+ .HL2 client state: decals, static ents, sounds)
  2. SV_InactivateClients, SV_FinalMessage, SV_DeactivateServer (frees edicts, strings)
  3. SV_SpawnServer(newmap, landmark)      — full BSP load (see doc 01)
  4. LoadGameState(newmap)                 sv_save.c:~1617 — restore this map's saved ents
  5. LoadAdjacentEnts(oldmap, landmark)    sv_save.c:~1918
     ├─ for each adjacent level's .HL1: parse tables
     ├─ offset = landmarkOrigin(new) - landmarkOrigin(old)   sv_save.c:~1963
     └─ CreateEntityTransitionList → pfnRestore per entity (landmark offset applied via
        FIELD_POSITION_VECTOR fields), EntityInSolid check kills stuck ents
  6. SV_ActivateServer(runPhysics=false)
```

## 3. Key data structures

- `ENTITYTABLE` (engine/eiface.h:~306): id, pent, location/size in buffer, flags, classname.
  Flags: `FENTTABLE_PLAYER|REMOVED|MOVEABLE|GLOBAL`; low 16 bits = bitmask of adjacent
  levels (MAX_LEVEL_CONNECTIONS = 16) the entity belongs to.
- `LEVELLIST` (eiface.h:~299): mapName[32], landmarkName[32], pentLandmark, vecLandmarkOrigin.
- `SAVERESTOREDATA`: shared engine↔gamedll save context; `fUseLandmark`, `vecLandmarkOffset`.
- `.HL1` = server entity state per map; `.HL2` = client state (decals etc.); these live in
  `save/` and effectively ARE Half-Life's "streaming" persistence layer between maps.

## 4. Per-map coordinate spaces

Each BSP has its own origin; adjacent maps OVERLAP in absolute coordinates. Alignment is
only defined pairwise via shared landmark entities:
`offset = landmark_pos_in_new_map - landmark_pos_in_old_map`. Decals: subtract on save,
add on load (sv_save.c:~1228, ~1338). Entities: hlsdk applies offset to
`FIELD_POSITION_VECTOR` fields automatically during restore.

**Consequence for true streaming:** to stitch two maps into one space, ALL geometry and
entities of the incoming map must be rigid-translated by the landmark delta. There is no
global world coordinate system in HL1 — it's a chain of pairwise landmark alignments.

## 5. Player handling

Player is saved/restored like other entities (FENTTABLE_PLAYER). Client is forced through
reconnect: client state set to cs_connected, `svc_serverdata` resent (spawncount bump),
client reloads world. `sv.loadgame = sv.paused = true` until client signs on again.

## 6. Global state

`CGlobalState` (hlsdk dlls/world.cpp) tracks `pev->globalname` entities across maps
(state OFF/ON/DEAD, name→map mapping). Serialized via pfnSaveGlobalState/RestoreGlobalState.

## 7. Stall sources during today's changelevel (in order)

1. SaveGameState: serialize all entities + 2 file writes (~10–50ms).
2. Server teardown (~20–50ms).
3. **Mod_LoadWorld BSP load (~100–500ms+) — dominant.**
4. LoadGameState: read .HL1 + pfnRestore loop (~30–100ms).
5. LoadAdjacentEnts: per adjacent level, file read + restore (~50–200ms each).
6. SV_ActivateServer + client reconnect + client-side asset load (textures/sounds —
   often the dominant cost client-side).
Total: ~0.4–2s+; plus the deliberate full disconnect/reconnect machinery and loading plaque.

## 8. Useful existing hooks

- `sv.background` (background map for menu) — proves engine can run a map "invisibly".
- `cls.changelevel` flag already suppresses CL_ClearState/music-stop on the client —
  the engine already special-cases transitions to be *less* destructive.
- The adjacency LEVELLIST + entity level-bitmask machinery is effectively a static
  streaming graph already encoded in the maps (trigger_changelevel + trigger_transition).
