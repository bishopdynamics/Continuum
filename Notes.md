# Notes


## small things

- in the game menu (with newgame, loadgame, savegame), remove the "preview" image on the right side of the page, it is the same as the background image so it looks weird

- it would be incredibly cool if we could add a "Chapters" button on the game menu (under newgame), with a list of all the chapters in the game, and it takes you to the first level of that chapter. 
  - out of scope for now: give the user the hazard suit, crowbar, and shotgun (even better, give them only the weapons they should have at this point, but how can we know that?)

- when clicking things in the UI, we get the classic menu sounds (which i like). Can we use these sounds for gamepad navigation too?

- scripted menu tour
  - we have done some testing where you navigated the menus to test something
  - can we do the same thing, from a script, to do our menu tour? 
  - this would be better than our fixed recording length, only as long as it takes to do all the steps in the script
  - 

- Test chamber ladder: the shadow on this ladder is about 20 units offset from the actual ladder, horizontally
  - might just be a map error that we can't do anything about, most other ladders are OK
- test chamber elevator: the sample elevator does not receive entity shadows, it is a moving brush i think

- console: lines seem to be limited length and wrap, but it is narrower than the screen width. math was probably meant for 4:3 originally


- after changing windowed mode / resolution, sometimes the text size of the menu UI is incorrect until restart

- the demo "cascade" routinely fails to render some things. Feels like the full data needed to play the demo is not getting loaded. This happens the same if we do `xash3d -playdemo` (like our capture-demo script) and if i just use the "playdemo" command in console
  - its actually worse than i thought: if i load a savegame from around the same area (on the tram, about 10 seconds from arriving at anomolous materials), i get the same issue. We broke this somehow in our changes on June 16th, need to bisect
  - if i go back and start a new game (which loads all the assets including the tram), it looks fine, and then if i load the savegame or play the demo, it also looks fine. Playdemo and loadgame are not doing preload hook right, or perhaps its a race condition?

## Remaining roadmap to v1 release

- complete the items in sections above this section (if any)
- before any public release: 
  - tighten the flatpak grant (currently --filesystem=home + --device=all)
  - documentation (see section below)


## Github Repositories

Umbrella project: https://github.com/bishopdynamics/Continuum
xash3d fork: https://github.com/bishopdynamics/xash3d-fwgs
mainui fork: https://github.com/bishopdynamics/mainui_cpp
hlsdk fork: https://github.com/bishopdynamics/hlsdk-portable


## Deferred Items

### Deferred: screenshot-each-map (auto chapter thumbnails)

Support for the Chapters menu: an engine feature that captures a screenshot
right after each map finishes loading and writes it as
`<gamefolder>_<map>.png` (e.g. `valve_c2a2.png`). These feed the chapter
thumbnails consumed by the Chapters menu.

- thumbnail convention + placeholder already in place:
  `redist/continuum/gfx/shell/continuum/chapters/` (see README.txt there)
- the menu loads `chapters/<gamefolder>_<map>.png`, falling back to
  `placeholder.png` when absent
- until this lands, thumbnails are captured/placed by hand
- open questions: where the engine writes captures (probably the game's
  writable dir) vs. where they ship from (`redist/continuum`); whether to
  capture only first-of-chapter maps or every map; framing/timing of the
  grab (after the frozen preload frame, before the player moves)

### Deferred: non-linux platform suport

- windows: i dont have a machine to test, and I dont care
- macos: 32bit/64bit compatibility issues


### Deferred: FBO-based shadow map (resolution + soft blur) — NOT doing now

The flashlight shadow map currently renders the light's depth into a *corner of the
visible back-buffer* and copies it out (`glCopyTexSubImage2D`), so its resolution is
hard-capped to the window size (screen height). It is also desktop-GL-only
(`#if !XASH_GLES`).

Moving the shadow render into a real off-screen **FBO** (depth-texture attachment)
would:
- decouple resolution from the window (up to `GL_MAX_TEXTURE_SIZE`, e.g. 2048/4096)
  → crisper shadow edges
- enable a real, wide, *soft* shadow blur (the AO/entity-shadow features get their
  soft edges from a CPU box-blur of a fake-silhouette coverage bitmap; that trick
  does NOT transfer to the flashlight, whose shadow is a real hardware depth-compare
  — blurring that needs an FBO + blur pass, or expensive multi-tap PCF)
- also simplify/clean up the current render-into-corner + copy hack

Why deferred: it would be the renderer's **first FBO**. The rest of ref/gl is
deliberately FBO-free for portability (Deck / GLES / GLSL-risk). Platform risk is
actually low here (the shadow map is already desktop-GL-only, and we'd keep the
corner method as a fallback), but it's a real architectural line to cross and the
payoff is quality-only (the acne — the thing that looked bad — is already fixed).
Revisit only if we decide we want *soft* flashlight shadows; resolution alone isn't
worth it. One FBO buys both.
