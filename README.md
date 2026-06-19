# Half-Life: Continuum Edition

A fork of the Xash3D-FWGS engine that plays Half-Life **start to finish with no
loading screens**, behind a unified controller-first menu — plus a few optional
visual and quality-of-life extras. Same game, same content, smoother ride.

> Created with assistance from Anthropic Fable 5, Opus 4.8, and Zennthic
> Elefant second-brain memory system.

![The Continuum menu](doc/media/menu-tour.gif)

## What this is — and isn't

**It is not** a mod, a remaster, or a content pack. There is no new or modified
content, story, or gameplay. You play the same Half-Life you already own.

**It is** a fork of the Xash3D-FWGS engine that adds:

- a new **unified, controller-first menu UI**, with a few existing settings
  exposed that the stock menu hid — mostly a new "theme" over the same engine;
- controller bindings by default
- a **"level streaming system"** — play the whole campaign with no loading
  screens ([details](doc/level-streaming.md));
- an optional, configurable **projected flashlight**
  ([details](doc/flashlight.md));
- supplemental **ambient occlusion**, contact and world
  ([details](doc/ambient-occlusion.md));
- reworked entity shadows (Xash3D already had experimental entity shadows, I just tweaked it)
- a few additional **quality-of-life settings**, all optional.

## Getting started

Continuum needs the original Half-Life game data — it doesn't ship any.

1. Get a build (release artifacts: linux-amd64 tarball, Steam Deck flatpak,
   Windows, macOS) **or** [build from source](doc/building.md).
2. Drop your retail Steam `valve/` folder (or an expansion/mod folder) in next
   to the engine.
3. Launch — pick your game from the menu and play.

Building it yourself instead? See **[doc/building.md](doc/building.md)** —
in short, `git clone --recurse-submodules`, then `make play`.

## Compatibility

- **Games & mods:** primary support: Half-Life, Opposing Force, Blue Shift, Uplink, They Hunger, USS darkstar. However, the same expansions and mods supported by upstream Xash3D-FWGS should work
  - Use Steam version of games where available
- **Savegames:** existing Xash3D-FWGS savegames should load (not exhaustively
  tested).

## Documentation

- [The menu](doc/menu.md) — the unified controller-first UI
- [Level streaming](doc/level-streaming.md) — how the no-loading-screen
  campaign works
- [Flashlight](doc/flashlight.md) — the optional projected flashlight
- [Ambient occlusion](doc/ambient-occlusion.md) — contact + world AO
- [Console variable reference](doc/cvars.md) — every cvar and command Continuum
  adds
- [Building from source](doc/building.md)

This project documents only what it *adds* to the engine — for the engine
itself, see the upstream Xash3D-FWGS documentation.

## Repositories

Continuum is an umbrella project over three engine/SDK forks:

- Umbrella: <https://github.com/bishopdynamics/Continuum>
- Engine fork (Xash3D-FWGS): <https://github.com/bishopdynamics/xash3d-fwgs>
- Menu fork (mainui_cpp): <https://github.com/bishopdynamics/mainui_cpp>
- Game SDK fork (hlsdk-portable): <https://github.com/bishopdynamics/hlsdk-portable>
