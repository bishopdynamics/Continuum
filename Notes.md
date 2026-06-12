# Notes

My running notes

## Small things

- for the mid-game menu (where it has "resume"): can we add "Main Menu" button? User wants a way to quit the campaign they are playing, and return to the root menu.

## Medium things

[none currently — 2026-06-12 round done: open game list (any installed mod streams),
single play-continuum.sh launcher, Continuum bindings + gamepad + multiplayer screens,
themed OK/Cancel dialogs. One stock page remains reachable: Character Setup
(player model/colors) under Multiplayer.]

## Big things

- settings toggle to disable modern UI
  - also need to add toggle to original UI so it can be enabled
  - probably requires restart, but would be nice if it does not
  - not concerned with adding advanced settings to original UI, unless it is trivial to do so
- need to move functionality of hlstream_preprocess.py into the engine, to be self-contained and cross-platform
- need to create build_all.sh, to build for distribution
  - windows x86, linux x86/arm64, macos arm64
  - other platforms must built it themselves


## Insane things

Some of these ideas mess with core gameplay, and would definitely be default-off

- improved flashlight. we have more powerful hardware now, can we do a better dynamic flashlight?
- improved map lighting
  - turn lights into dynamic lights
  - ambient occlusion? (would prefer to avoid screen-space AO)
  - keep the baked lighting, just turn down the "intensity", and let the dynamic lighting contribute better shadows mostly
  - any of this already exist in xash3d?
- gameplay tweaks
  - disable flashlight battery (infinite battery)
  - unlink flashlight battery from Oxygen level (cant hold breath as long with flashlight on currently)
  - add "always run" toggle
  - unify jump/swim-up and crouch-swimdown: currently separate keybindings for jump and swim-up, and users often dont use swim up/down as a result. 


## Documentation

- Readme, using similar style as our new unified menu
  - This is not a mod or a "remaster"
  - There is no modified or additional content or gameplay
  - supported expansions/mods list is same as upstream xash3d-fwgs
  - This is:
    - a new unified menu system, with a few more (existing) settings exposed
    - a level streaming system (no more loading screens)
  - 
- Capture a 10fps video tour of new menu, convert to GIF so we can use it in the Readme.md
- help me record a demofile starting at the end of the opening tram ride, thru to the blackout after the resonance cascade (that might actually be all of day one?). Then capture that to a 30fps video, for us to use as a gameplay video. I want a pipeline so we can re-capture the video from the demofile any time we want.
