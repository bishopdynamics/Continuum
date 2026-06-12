# Notes

My running notes

## Small things

[none currently — 2026-06-12 round 5 done: character preview pane sized to never
overlap the rows; OSK takes d-pad now (raw K_DPAD_* was falling through to the
menu); the 2-3-letter jumps were an engine bug — the stick-to-dpad simulation
reported threshold-crossing edges and double-edge-detected, so analog jitter
hammered press/release pairs. Now state-based with hysteresis; this also fixes
stick navigation skipping in regular menus. Stick now works in in-game chat too.
Verify the stick/d-pad feel with the DualSense.]


## Big things

- did we break savegame compatibility with any of our changes? 
- settings toggle to disable modern UI
  - also need to add toggle to original UI so it can be enabled
  - probably requires restart, but would be nice if it does not
  - not concerned with adding advanced settings to original UI, unless it is trivial to do so
- need to move functionality of hlstream_preprocess.py into the engine, to be self-contained and cross-platform
- need to create build_all.sh, to build for distribution
  - windows x86, linux x86/arm64, macos universal
  - steam deck flatpak? 
    - x86 and arm64, because upcoming valve arm64 hardware
    - need to document where user needs to place game folders
  - other platforms must built it themselves
- the console takes a long time to open on higher resolutions, feels like the console-open animation is hardcoded as a certain pixels per second, instead of normalized to screen size.
  - user also wants to control console font size in advanced settings with a slider

## Insane things

Some of these ideas mess with core gameplay, and would definitely be default-off

- improved flashlight. we have more powerful hardware now, can we do a better dynamic flashlight?
- gameplay tweaks
  - disable flashlight battery (infinite battery)
  - unlink flashlight battery from Oxygen level (cant hold breath as long with flashlight on currently)
  - add "always run" toggle
  - unify jump/swim-up and crouch-swimdown: currently separate keybindings for jump and swim-up, and users often dont use swim up/down as a result. enabling this setting causes the jump key to also do swim-up, and crouch to also do swim-down
- improved map lighting (we probably wont do this one)
  - turn lights into dynamic lights
  - ambient occlusion? (would prefer to avoid screen-space AO)
  - keep the baked lighting, just turn down the "intensity", and let the dynamic lighting contribute better shadows mostly
  - any of this already exist in xash3d?

## Documentation

- Readme, using similar style as our new unified menu
  - This is not a mod or a "remaster"
  - There is no modified or additional content or gameplay
  - supported expansions/mods list is same as upstream xash3d-fwgs
  - not really tuned for multiplayer
  - This is:
    - a new unified menu system, with a few more (existing) settings exposed; mostly just a new "theme"
    - a level streaming system (no more loading screens)
  - 
- Capture a 10fps video tour of new menu, convert to GIF so we can use it in the Readme.md
- help me record a demofile starting at the end of the opening tram ride, thru to the blackout after the resonance cascade (that might actually be all of day one?). Then capture that to a 30fps video, for us to use as a gameplay video. I want a pipeline so we can re-capture the video from the demofile any time we want.
