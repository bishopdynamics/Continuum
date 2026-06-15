# The menu

Continuum replaces the stock Xash3D menu with a unified, **controller-first**
UI. It's the most visible change in the project — but it's only a new front end:
same engine, same games, no new content.

![Menu tour](media/menu-tour.gif)

## What's different

- **Controller-first.** The whole menu is built to be driven with a gamepad
  (and works the same with mouse and keyboard) — navigation, the game picker,
  and every settings screen.
- **One launcher for every game.** Installed expansions and mods (Opposing
  Force, Blue Shift, They Hunger, Uplink, …) show up in a single game picker
  rather than needing separate shortcuts.
- **More settings exposed.** A handful of useful settings that the stock menu
  hid behind the console are surfaced directly, alongside the Continuum-specific
  options (level streaming, the [flashlight](flashlight.md), and
  [ambient occlusion](ambient-occlusion.md)).

Under the hood the settings screens just read and write the same cvars listed in
the [cvar reference](cvars.md), so anything you can set in the menu you can also
set from the console or a `.cfg`, and vice-versa.
