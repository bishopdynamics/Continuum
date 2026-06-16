# Notes

## small things

- flashlight vertical offset: -8
  - the suit's flashlight is actually on the chest. Also this produces the coolest looking shadows


## medium things


- I'm seeing an issue where a scientist walking around suddenly becomes darker (like he stepped out of a light), and then as they keep walking they become lit again. I tried turning off all our new features, and it looks like this is a pre-existing feature of xash3D. It's some kind of dynamic lighting on entities from map lights, but it seems to be sampling at a very low rate, or doesn't have fine-grained enough light levels to switch between, because they "pop" between different light levels as they walk around. My question: can we find this feature, and give it some more granularity? 

- uplink is actually legal to distribute, we could include so that Continuum has _some_ content by default
- 

## Remaining roadmap to v1 release

- complete the items in sections above this section (if any)
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


## Github Repositories

Umbrella project: https://github.com/bishopdynamics/Continuum
xash3d fork: https://github.com/bishopdynamics/xash3d-fwgs
mainui fork: https://github.com/bishopdynamics/mainui_cpp
hlsdk fork: https://github.com/bishopdynamics/hlsdk-portable


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
