# Notes

## small things

- in settings, some rows have an explainer card on the right, most dont. Can we add some more of those, particularly for the features we added? it doesn't have to be every single setting, but anything that benefits from a more detailed explanation

## medium things

- flashlight moire pattern on illuminated surfaces, gets worse when closer to the camera
- entity shadows: if the "floor" that the shadow would draw on is more than 64 units away from the bounds of the entity (the entity's feet), skip that shadow. This is to address a spot in the opening tram ride, where a character (far away) is walking on a raised platform, but the shadow is landing on the floor below the platform.
- I'm seeing an issue where a scientist walking around suddenly becomes darker (like he stepped out of a light), and then as they keep walking they become lit again. I tried turning off all our new features, and it looks like this is a pre-existing feature of xash3D. It's some kind of dynamic lighting on entities from map lights, but it seems to be sampling at a very low rate, or doesn't have fine-grained enough light levels to switch between, because they "pop" between different light levels as they walk around. My question: can we find this feature, and give it some more granularity?

## Remaining roadmap to v1 release

- macos universal build still needs a Mac (tools/build_all.sh prints guidance)
- win32+wine controller hotplug unreliable — needs a real-Windows test
- rebuild + reship the dist artifacts (linux-amd64 tarball + flatpak) so they include all the menu changes (HD toggle, cheats, flashlight)
- separate build scripts for:
  - linux-amd64, linux-arm64, linux-flatpak (amd64 only for now)
  - Windows-amd64
  - macos-universal
- before any public release: 
  - tighten the flatpak grant (currently --filesystem=home + --device=all)
  - documentation (see section below)


## Documentation

This comes last, when we are almost ready to release, and after we decided what insane things to implement.

our current ./docs/ folder is actually just research, and should be renamed and gitignored

- Readme, using similar style as our new unified menu
  - what this is not:
    - This is not a mod or a "remaster"
    - There is no modified or additional content or gameplay
  - This is:
    - a fork of the xash3d engine
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
  - include, near the top our AI attribution line: Created with assistance from Anthropic Fable 5, Opus 4.8, and Zennthic Elefant second-brain memory system
  - 

## Github Repositories

Umbrella project: https://github.com/bishopdynamics/Continuum
xash3d fork: https://github.com/bishopdynamics/xash3d-fwgs
mainui fork: https://github.com/bishopdynamics/mainui_cpp
hlsdk fork: https://github.com/bishopdynamics/hlsdk-portable


