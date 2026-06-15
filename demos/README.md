# Demos

Recorded playthroughs on the xash3d-streaming engine, kept for re-rendering into
gameplay videos (the demo stores game state, so playback re-renders live with
whatever engine/settings are current).

Render any of them to an MP4 with `tools/capture-demo-video.sh <demo>` (e.g.
`tools/capture-demo-video.sh tram_ride`); it warms the campaign preload, plays
the demo, and dumps frames straight from the engine to ffmpeg (tear-free, with
audio). Output lands in `dist/<demo>.mp4` (a release asset, not committed).

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

## tram_ride.dem

The **full opening tram ride** — from the very start of Black Mesa Inbound
(`c0a0`) through the tram sequence, across its level transitions. This is the
opening that `cascade.dem` joins partway through, so it's the better showcase of
the seamless streaming during the ride itself.

Recorded 2026-06-14 (on the offline AO-bake engine — no per-map hitches).

### Play it

```sh
cp demos/tram_ride.dem install/valve/tram_ride.dem
./play-continuum.sh valve +playdemo tram_ride
```

## zombie_shadows.dem

A short clip in **Blast Pit** (`c1a4d`) showing off the dynamic entity shadows —
moving characters casting soft AO-style projected shadows on the baked world.

Recorded 2026-06-14.

### Play it

```sh
cp demos/zombie_shadows.dem install/valve/zombie_shadows.dem
./play-continuum.sh valve +playdemo zombie_shadows
```
