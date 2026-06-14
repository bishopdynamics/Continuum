# Demos

Recorded playthroughs on the xash3d-streaming engine, kept for re-rendering into
gameplay videos (the demo stores game state, so playback re-renders live with
whatever engine/settings are current).

## cascade.dem

A continuous run from the **opening tram ride** (Black Mesa Inbound) straight
through to **just past the resonance cascade** — one recording across every level
transition (no loading screens). A good end-to-end showcase of the additions:

- the Continuum controller-first menu,
- seamless level streaming (the whole run is one demo),
- the improved projected-cookie flashlight,
- ambient occlusion — contact AO under entities/props **and** baked world AO.

Recorded 2026-06-14.

### Play it

```sh
cp demos/cascade.dem install/valve/cascade.dem
./play-continuum.sh valve +playdemo cascade
```

### Notes

- It was recorded with **world AO auto-baking per map** (the current stop-gap),
  so there's a brief per-map hitch baked into the timing and a couple of fast
  tram segments may lack world AO. Re-record once the **preload bake** lands
  (front-loaded, no hitches) for the final video.
- Ends when the player is killed by a laser shortly after the cascade.
