# Notes

My running notes



## Remaining roadmap to v1 release

- settings toggle to disable modern UI
  - also need to add toggle to original UI so it can be enabled
  - probably requires restart, but would be nice if it does not
  - not concerned with adding advanced settings to original UI, unless it is trivial to do so
- need to create build_all.sh, to build for distribution
  - windows x86, linux x86/arm64, macos universal
  - steam deck flatpak? 
    - x86 and arm64, because upcoming valve arm64 hardware
    - need to document where user needs to place game folders
  - other platforms must built it themselves

## Cheats menu

- goes in the mid-game menu, if enabled
- toggle in advanced settings to enable cheats. enables the button, and sets sv_cheats
- cheats need to re-apply on level change, since it is now seamless to the user


## Insane things

Some of these ideas mess with core gameplay, and would definitely be default-off

- improved flashlight. we have more powerful hardware now, can we do a better dynamic flashlight?
- gameplay tweaks
  - disable flashlight battery (infinite flashlight)
  - unlink flashlight battery from Oxygen level (cant hold breath as long with flashlight on currently)
    - thus, flashlight becomes infinite but oxygen stays same as as before
  - add "always run" toggle
  - unify jump/swim-up and crouch/swim-down: currently separate keybindings for jump and swim-up, and users often dont use swim up/down as a result. enabling this setting causes the jump key to also do swim-up, and crouch to also do swim-down
- improved map lighting (we probably wont do this one)
  - turn lights into dynamic lights
  - ambient occlusion? (would prefer to avoid screen-space AO)
  - keep the baked lighting, just turn down the "intensity", and let the dynamic lighting contribute better shadows mostly
  - any of this already exist in xash3d?

## Documentation

This comes last, when we are almost ready to release, and after we decided what insane things to implement.

- Readme, using similar style as our new unified menu
  - what this is not:
    - This is not a mod or a "remaster"
    - There is no modified or additional content or gameplay
  - This is:
    - a new unified controller-first menu UI, with a few more (existing) settings exposed; mostly just a new "theme"
    - a level streaming system (no more loading screens)
    - a few additional quality-of-life settings, all optional and off-by-default
  - compatibility:
    - supported expansions/mods list is same as upstream xash3d-fwgs
    - existing xash3d-fwgs savegames should work (not thoroughly tested)

- Capture a 10fps video tour of new menu, convert to GIF so we can use it in the Readme.md
- help me record a demofile starting at the end of the opening tram ride, thru to the blackout after the resonance cascade (that might actually be all of day one?). Then capture that to a 30fps video, for us to use as a gameplay video. I want a pipeline so we can re-capture the video from the demofile any time we want.
