# Demos

Recorded playthroughs on the xash3d-streaming engine, kept for re-rendering into
gameplay videos (the demo stores game state, so playback re-renders live with
whatever engine/settings are current).

## cascade.dem

A continuous run from the **Black Mesa Inbound approach** (the final tram leg
into the security checkpoint) straight through to **just past the resonance
cascade** — one recording across every level transition (no loading screens). A
good end-to-end showcase of the additions:

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

- Recorded on the **front-loaded AO preload bake** engine: world AO is baked
  offline at first launch and loaded per map, so this run has no per-map bake
  hitch in its timing (the earlier take did — it predated the offline bake).
- Recording starts on `c0a0d`: the engine requires you to already be in a level
  to `record`, so the first few seconds of the tram (`c0a0`–`c0a0c`) are not in
  this take.
- Ends when the player is killed by a laser shortly after the cascade.
