# Notes

My running notes


## small things

- win32-i386 build, playing via wine, has just enough of a stutter on level change to be annoying, definitely takes longer than on native linux
- on Steam Deck (flatpak), the built-in controller was NOT auto-detected for the glyph set — menu showed the wrong/default glyphs. Workaround exists (manual glyph-set setting in the menu), but we should dig into why SDL/joystick detection didn't pick the Deck's gamepad and map it to the right glyph family (ps/xbox/switch/etc.). Probably needs Deck VID/PID or SDL_GameControllerType handling.
- 


## Remaining roadmap to v1 release

- ~~need to create build_all.sh, to build for distribution~~ DONE: tools/build_all.sh
  - containerized (Docker) builds: linux-amd64, linux-arm64 (qemu binfmt), win32 (mingw, validated under wine incl. in-game)
  - macos universal still needs a Mac (script prints guidance)
  - user setup documented in tools/dist/README-DIST.md (ships inside each artifact)
  - known caveat: controller hotplug under win32+wine unreliable; needs a real-Windows test
- ~~steam deck flatpak~~ DONE (x86_64): tools/dist/build-flatpak.sh + ./install-deck.sh
  - assembled from the linux-amd64 tree (no flatpak SDK needed); app id org.continuum.HalfLife
  - uses engine RODIR (read-only /app overlay: game libs + fonts) + writable BASEDIR (app data dir)
  - validated in a real sandbox: campaign preloads, c1a0 loads, writes land in data dir, /app read-only
  - install: DECK_SSH=deck@host ./install-deck.sh [--run]; game data -> ~/.var/app/<id>/data/valve
  - arm64 flatpak deferred until Valve ships arm64 hardware (would just need an arm64 base tree)
  - battle-test grant is --filesystem=home + --device=all; tighten before any public release
- ~~support the "HD" content (valve_hd, bshift_hd, gearbox_hd) if present~~ DONE (basic toggle)
  - engine already had the plumbing: fs_mount_hd cvar mounts <gamedir>_hd, applied live via fs_rescan
  - "HD Models" toggle added to the Continuum Config > Interface tab (mainui submodule, Config.cpp)
    - shown ONLY when a <gamedir>_hd pack is detected (probes models/gman|barney|agrunt.mdl via the base path)
    - onChanged runs fs_rescan so it mounts/unmounts without a restart; persists to vfs.cfg (writable basedir, not the read-only flatpak /app)
    - validated in-engine: row appears, toggles, mounts valve_hd; works for any game's _hd
  - STRETCH (deferred): split HD into per-category model toggles in a submenu — needs custom
    partial mounting (the engine's fs_mount_hd is all-or-nothing), a real feature, not plumbing.
    Decide whether it's worth it; GoldSrc itself is all-or-nothing here.
  - NOTE: dist artifacts (linux-amd64 tarball + flatpak) need a rebuild to ship this menu change

## Cheats menu

- toggle in advanced settings to enable cheats. enables the button, and sets sv_cheats
- goes in the mid-game menu, if enabled
- toggle cheats need to re-apply on level change, since it is now seamless to the user
  - otherwise god mode silently turns off without user knowing
- cheats list:
  - toggles for: god, notarget, noclip, thirdperson
  - buttons for: impulse 101, impulse 195, impulse 105, give item_battery, give item_healthkit, give item_suit, give item_longjump
- hopefully this set of cheats is generic enough that we don't need to do any per-game logic; user can always use the console


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
