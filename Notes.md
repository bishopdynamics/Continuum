# Notes

My running notes


## small things

- root menu and mid-game menu:
  - need to shift all items up. When mid-game menu and cheats enabled, the quit button is almost off the screen (it is behind the input prompts panel)
- win32-i386 build, playing via wine, has just enough of a stutter on level change to be annoying, definitely takes longer than on native linux
- on Steam Deck (flatpak), the built-in controller was NOT auto-detected for the glyph set — menu showed the wrong/default glyphs. Workaround exists (manual glyph-set setting in the menu), but we should dig into why SDL/joystick detection didn't pick the Deck's gamepad and map it to the right glyph family (ps/xbox/switch/etc.). Probably needs Deck VID/PID or SDL_GameControllerType handling.
- in menus, the on-hover/on-highlighted animation is triggered repeatedly as mouse moves over the button. should only be triggered when entering the button area

## Remaining roadmap to v1 release

- macos universal build still needs a Mac (tools/build_all.sh prints guidance)
- win32+wine controller hotplug unreliable — needs a real-Windows test
- rebuild + reship the dist artifacts (linux-amd64 tarball + flatpak) so they include all the menu changes (HD toggle, cheats, flashlight)
- before any public release: tighten the flatpak grant (currently --filesystem=home + --device=all)
- (deferred) split HD into per-category model toggles — needs custom partial mounting (fs_mount_hd is all-or-nothing); decide whether it's worth it
- (deferred) arm64 flatpak — until Valve ships arm64 hardware


## Insane things

Some of these ideas mess with core gameplay, and would definitely be default-off

- gameplay tweaks
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
    - a new flashlight (optional, configurable)
    - a few additional quality-of-life settings, all optional and off-by-default
  - compatibility:
    - supported expansions/mods list is same as upstream xash3d-fwgs
    - existing xash3d-fwgs savegames should work (not thoroughly tested)

- Capture a 10fps video tour of new menu, convert to GIF so we can use it in the Readme.md
- help me record a demofile starting at the end of the opening tram ride, thru to the blackout after the resonance cascade (that might actually be all of day one?). Then capture that to a 30fps video, for us to use as a gameplay video. I want a pipeline so we can re-capture the video from the demofile any time we want.
