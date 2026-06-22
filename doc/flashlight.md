# Flashlight

Continuum ships an optional **projected-texture flashlight** as an alternative
to the stock dynamic-light flashlight. It is **off by default** — set
`r_flashlight_projected 1` (or toggle it in the [settings menu](menu.md)) to
turn it on.

## What it adds

- **A real projected cone** instead of a fuzzy point-light blob — a focused
  hotspot beam plus a wider, dimmer spill halo around it.
- **Dynamic shadows.** The beam casts shadow maps, so geometry and entities
  between you and a surface block the light.
- **Texture-aware lighting.** The cone can modulate by the surface texture it
  lands on rather than flat-adding white.



## Tuning it

The beam, spill, range, shadows, and eye offset are all configurable. See the
[flashlight cvars](cvars.md#flashlight) for the full list with defaults and
ranges. A few common tweaks:

- **Tighter / wider beam** — `r_flashlight_cone` (hotspot) and
  `r_flashlight_spill_cone` (halo).
- **Brighter / dimmer** — `r_flashlight_intensity` (beam) and
  `r_flashlight_spill_intensity` (halo).
- **Sharper shadows** — raise `r_flashlight_shadow_size` (costs more GPU);
  set `r_flashlight_shadows 0` to disable shadows entirely.
- **Reach** — `r_flashlight_range`.
