# Notes

My running notes


## small things

- win32-i386 build, playing via wine, has just enough of a stutter on level change to be annoying, definitely takes longer than on native linux

## Insane things

Some of these ideas mess with core gameplay, and would definitely be default-off

- gameplay tweaks
  - unlink flashlight battery from Oxygen level (cant hold breath as long with flashlight on currently)
    - thus, flashlight becomes infinite but oxygen stays same as as before
  - add "always run" toggle (right now the game is always-run by default and cant turn it off)

- graphics improvements
  - ambient occlusion (prefer not screen-space, but will take what I can get)
  - improved map lighting (we probably wont do this one)
    - turn lights into dynamic lights
    - keep the baked lighting, just turn down the "intensity", and let the dynamic lighting contribute better shadows mostly
    - any of this already exist in xash3d?




## Remaining roadmap to v1 release

- macos universal build still needs a Mac (tools/build_all.sh prints guidance)
- win32+wine controller hotplug unreliable — needs a real-Windows test
- rebuild + reship the dist artifacts (linux-amd64 tarball + flatpak) so they include all the menu changes (HD toggle, cheats, flashlight)
- before any public release: tighten the flatpak grant (currently --filesystem=home + --device=all)
- (deferred) split HD into per-category model toggles — needs custom partial mounting (fs_mount_hd is all-or-nothing); decide whether it's worth it
- (deferred) arm64 flatpak — until Valve ships arm64 hardware



## Documentation

This comes last, when we are almost ready to release, and after we decided what insane things to implement.

- Readme, using similar style as our new unified menu
  - what this is not:
    - This is not a mod or a "remaster"
    - There is no modified or additional content or gameplay
  - This is:
    - a new unified controller-first menu UI, with a few more (existing) settings exposed; mostly just a new "theme"
    - a level streaming system (no more loading screens)
    - a new flashlight (optional, configurable)
    - supplemental ambient occlusion (optional)
    - a few additional quality-of-life settings, all optional and off-by-default
  - compatibility:
    - supported expansions/mods list is same as upstream xash3d-fwgs
    - existing xash3d-fwgs savegames should work (not thoroughly tested)
  - Readme.md is just primarily "getting started" and minimal explanation of what this project is. everything else belongs in separate pages that you link to from here. This keeps the core Readme clean and focused on introducing new users to the project, but they can find all the detailed documentation from there.
  - we aren't here to document the whole engine ourselves
  - of course, we _must_ document all the cvars that we added

- Capture a 10fps video tour of new menu, convert to GIF so we can use it in the Readme.md
- help me record a demofile starting at the end of the opening tram ride, thru to the blackout after the resonance cascade (that might actually be all of day one?). Then capture that to a 30fps video, for us to use as a gameplay video. I want a pipeline so we can re-capture the video from the demofile any time we want.
