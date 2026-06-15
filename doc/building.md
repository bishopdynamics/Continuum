# Building from source

The top-level `Makefile` is the single front door for building and running.
Run `make` with no arguments to see every target.

## Get the source

The engine and game SDK are git submodules, so clone recursively:

```sh
git clone --recurse-submodules https://github.com/bishopdynamics/Continuum
cd Continuum
```

(Already cloned without `--recurse-submodules`? Run
`git submodule update --init --recursive`.)

## Build & run natively (development)

```sh
make play                       # rebuild the engine + launch
make play GAME=of               # launch a specific game (e.g. Opposing Force)
make play GAME=valve ARGS="-windowed +map c1a0"
```

`make play` runs `build-engine` first, so a plain `make build-engine` just
compiles without launching. To run, drop your retail Steam `valve/` folder (or
an expansion/mod folder) into `install/` — the demo `dayone` data is included.

## Distributable builds

These run in Docker for reproducibility; artifacts land in `dist/artifacts/`.

```sh
make linux          # linux-amd64 tarball + Steam Deck flatpak
make linux-arm64    # linux-arm64 tarball (needs qemu binfmt)
make windows        # win32 (i686) zip
make flatpak        # Steam Deck flatpak only
make macos          # macOS universal bundle (must run on a Mac)
```

See `tools/dist/README-DIST.md` for the packaging details.

## Steam Deck

```sh
make install-deck DECK_SSH=deck@steamdeck.local
```

builds the flatpak and installs it on a Deck over SSH.

## Housekeeping

```sh
make clean          # remove dist staging + artifacts
make distclean      # also reset the native (waf) build state for a clean reconfigure
```
