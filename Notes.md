# Notes


## small things

- scripted menu tour
  - we have done some testing where you navigated the menus to test something
  - can we do the same thing, from a script, to do our menu tour? 
  - this would be better than our fixed recording length, only as long as it takes to do all the steps in the script
  - 

- Test chamber ladder: the shadow on this ladder is abour 20 units offset from the actual ladder, horizontally
  - might just be a map error that we can't do anything about, most other ladders are OK
- test chamber elevator: the sample elevator does not receive entity shadows, it is a moving brush i think
- console: lines seem to be limited length and wrap, but it is narrower than the screen width. math was probably meant for 4:3 originally


- how do we handle client.so and client_amd64.so ?
  - user adds a new mod, it only has .dlls
  - do we need to build them per-game, or can we build them once along with the rest of the binaries, and then copy it into each game folder at startup?

- after changing windowed mode / resolution, sometimes the text size of the menu UI is incorrect until restart

- on a fresh game folder, new game is greyed out??

## medium things

- For world AO calculations, can we filter surfaces that we calculate based on size? I want to skip surfaces smaller than 64 units on either axis. This will fix an issue where there is a tiny 5x10 recessed shelf in a wall, and the floor of the shelf currently gets weird AO that shouldnt be there
  - we need a slider for this, range 8 to 512, default 64

- I'm seeing an issue where a scientist walking around suddenly becomes darker (like he stepped out of a light), and then as they keep walking they become lit again. I tried turning off all our new features, and it looks like this is a pre-existing feature of xash3D. It's some kind of dynamic lighting on entities from map lights, but it seems to be sampling at a very low rate, or doesn't have fine-grained enough light levels to switch between, because they "pop" between different light levels as they walk around. My question: can we find this feature, and give it some more granularity? 

- uplink is actually legal to distribute, we could include so that Continuum has _some_ content by default
  - so dist package becomes:
  - Continuum/
    - xash3d.exe
    - continuum/
    - uplink/
    - <user places valve folder here>

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
