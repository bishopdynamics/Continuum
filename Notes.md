# Notes

My running notes


## small things

- DONE (pending playtest): remove advanced setting "entity shadows" from the menu. Row removed from Config.cpp Advanced tab; r_shadows already defaults off so it stays off.

- gameplay tweaks
  - flashlight battery vs Oxygen: in the code these were never linked — oxygen is air_finished/AIRTIME in WaterMove(), the flashlight is m_iFlashBattery; turning the light on does not touch breath. The "flashlight becomes infinite" goal is already covered by the existing Infinite Battery toggle (Gameplay tab, flashlight_infinite cvar, default off). OPEN: decide whether infinite should be the default vs opt-in.
  - DONE (pending playtest): "always run" toggle (Gameplay tab). On = run by default, hold Shift to walk (stock). Off = walk by default, hold Shift to run. No new movement code — swaps cl_forwardspeed/back/side (400<->120) and cl_movespeedkey (0.3<->3.33, the speed key always multiplies so <1 walks / >1 runs). cl_movespeedkey made FCVAR_ARCHIVE in all 4 client builds so the inverted state persists.


## Big things

- improved map lighting
  - turn lights into dynamic lights, specifically to get real-time shadows and lighting
  - idea: keep the baked lighting, just turn down the "intensity", and let the dynamic lighting contribute better shadows mostly
  - any of this already exist in xash3d?




## Remaining roadmap to v1 release

- macos universal build still needs a Mac (tools/build_all.sh prints guidance)
- win32+wine controller hotplug unreliable — needs a real-Windows test
- rebuild + reship the dist artifacts (linux-amd64 tarball + flatpak) so they include all the menu changes (HD toggle, cheats, flashlight)
- before any public release: tighten the flatpak grant (currently --filesystem=home + --device=all)



## Documentation

This comes last, when we are almost ready to release, and after we decided what insane things to implement.

our current ./docs/ folder is actually just research, and should be renamed and gitignored

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
  - include, near the top our AI attribution line: Created with assistance from Anthropic Fable 5, Opus 4.8, and Zennthic Elefant second-brain memory system
  - 

- Capture a 10fps video tour of new menu, convert to GIF so we can use it in the Readme.md
- help me record a demofile starting at the end of the opening tram ride, thru to the blackout after the resonance cascade (that might actually be all of day one?). Then capture that to a 30fps video, for us to use as a gameplay video. I want a pipeline so we can re-capture the video from the demofile any time we want.
