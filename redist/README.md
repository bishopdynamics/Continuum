# redist/ — static content bundled into the dist packages

`tools/build_all.sh` stages everything here into every platform package,
alongside the engine and the per-mod game libraries it builds.

## What's here

- **`continuum/`** — Continuum's own always-mounted assets: fonts, controller
  glyphs, menu brand marks, and the menu's `resource/` localization. Committed,
  and **always** included in every package. (The per-game menu backgrounds under
  `gfx/shell/continuum/games/` are composed at runtime from the user's own game
  files, so they are deliberately *not* kept here and never ship.)

That's it. The package ships **no game content** — the engine, the `continuum/`
overlay, and the per-mod game libraries only; the user supplies `valve` and any
games/mods themselves (see `tools/dist/README-DIST.md`).

Anything else you drop in here (a `valve/` for local reference, an `uplink/`
mod, etc.) is **gitignored and NOT bundled** — game content is never committed
and never shipped. Only `continuum/` and this README are tracked.
