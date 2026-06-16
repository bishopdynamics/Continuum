# Elefant-Offline

Local cache of memories to replay into Elefant once it's back. Elefant's embedder
returned `403 Forbidden` for every search/list/capture call (session 2026-06-16),
so nothing could be consulted or written there. Each entry below is a captured
memory: tag with project `xash3d-continuum` (aka legacy `xash-streaming`) when
replaying.

---

## 2026-06-16 — Flashlight horizontal + vertical offset

- The projected flashlight (`xash3d-fwgs/ref/gl/gl_flashlight.c`) now has TWO
  position offsets off the eye:
  - `r_flashlight_offset` (vertical): default changed `4` → `-8` (chest level);
    clamp widened `-20..20` → `-24..24`. `+` above (headlamp), `-` below (chest).
  - `r_flashlight_offset_h` (horizontal, NEW): default `0`, clamp `-24..24`.
    `+` right (shoulder), `-` left, `0` centered.
- Horizontal offset is applied along a WORLD-horizontal "right" vector
  (`RI.vright` with Z zeroed then renormalized) so a shoulder offset stays level
  and doesn't drift up/down with view pitch. Vertical stays pure world-Z. The
  fixed `-28` backward step along vforward is unchanged.
- Menu: Customize Flashlight sub-page (`3rdparty/mainui/menus/continuum/Config.cpp`,
  `CMenuContFlashlight`) gained a "Horizontal Offset" slider beside the updated
  "Vertical Offset" slider — both `-24..24`, step 2, defaults `0` / `-8` — and
  both are in the reset-to-default (`X` key) handler. Page is now 10 rows; layout
  ends ~y=744 within the 768 virtual height (tight but fits, not yet eyeballed).
- Verified: `tools/build-engine.sh` → `BUILD-AND-INSTALL-OK` (covers renderer + menu).

## 2026-06-16 — demo capture pipeline consolidated into capture-demo.sh

- CONFIRMED (James tested): a recorded demo does NOT capture the menu UI — mainui
  isn't part of the demo stream. So demo→capture is gameplay-only; the menu tour
  must stay a hand-driven screen grab.
- NEW `tools/capture-demo.sh [demo]`: one demo run → BOTH `dist/media/<demo>.mp4`
  (H.264/NVENC master) and `dist/media/<demo>.gif` (small, derived from the MP4 via
  2-pass palettegen/paletteuse). With NO arg it batch-captures every `demos/*.dem`.
  - Reuses the `startmovie` FIFO pipeline (glReadPixels, no screen grab → no tearing).
  - GIF is built from the finished MP4 (lossy source is imperceptible at GIF's
    downscaled fps/size, and avoids a huge lossless temp).
  - Idempotent: valid MP4 present → skip; only GIF missing → rebuild from MP4 (no
    re-capture); `FORCE=1` re-captures. Validate-by-size + retry (RETRIES, MIN_MB)
    guards the rare tiny-truncated-file failure.
  - Env: GAME/WIDTH/HEIGHT/FPS/FPS_CAP/VSYNC, ENCODER/CQ/NVENC_PRESET/CRF/PRESET,
    AUDIO/AUDIO_DEV/ABITRATE, GIF_FPS/GIF_WIDTH, MIN_MB/RETRIES/FORCE/OUTDIR.
- REPLACES (all removed): `capture-demo-video.sh`, `capture-all-demo-videos.sh`,
  `capture-gif-of-gameplay.sh`.
- `tools/capture-menu-gif.sh` KEPT (hand-driven x11grab; only thing that can grab
  the menu). Reworked to take an optional name and output `dist/media/<name>.gif`
  (default `menu-tour`) instead of writing `doc/media/` directly — so it matches the
  workflow: shoot candidates into dist/media/, hand-pick the best into
  doc/media/menu-tour.gif (still embedded by README.md and doc/menu.md).
- Gotcha hit + fixed: under `set -u`, `local a=$1 b="$a..."` errors ("a: unbound")
  because bash expands ALL of `local`'s args before assigning any — split into two
  `local` statements.
- Verified end-to-end on `demos/zombie_shadows.dem`: attempt 1 hit the tiny-file
  failure, auto-retried, attempt 2 produced MP4 (38M) + GIF; skip and
  rebuild-gif-only paths both verified. (zombie_shadows is long → ~27 MB GIF at
  480px; use short demos + lower GIF_FPS/GIF_WIDTH for README sizes.)
- SESSION_START.md now (James's edit) points here as the offline Elefant cache:
  replay these into Elefant when it's back, then delete the replayed entries.

## 2026-06-16 — entity lighting "popping" fixed with bilinear point-lightmap filter

- Root cause of NPCs (e.g. scientists) popping between light levels as they walk:
  `R_RecursiveLightPoint` in `xash3d-fwgs/ref/common/ref_light.c` sampled the world
  lightmap with NEAREST luxel (`Q_rint(dt)*smax+Q_rint(ds)`). Luxels are ~16 units
  apart, so a moving entity's light value steps in 16-unit jumps. NOT temporal/low
  sample rate — it's recomputed every frame; the coarseness is spatial (the luxel
  grid). The floor under them looks smooth because world surfaces get GPU bilinear
  lightmap filtering; entities sampled nearest, hence the pop against smooth ground.
- Path: R_StudioDrawModel → R_EntityDynamicLight (ref_light.c) → R_LightVec →
  R_LightVecInternal → R_RecursiveLightPoint (the nearest-luxel read). Same path
  also feeds sprite lighting, R_GatherPlayerLight (player light-level HUD), and the
  entity-shadow direction (gl_entshadow.c already temporally smooths the snap).
- FIX (implemented, NOT yet committed): new cvar `r_lighting_filter` (default "1",
  FCVAR_ARCHIVE) + helper `R_LightmapBilinear`. When on, bilinearly blends the 4
  surrounding luxels (clamped to the grid) for both the lightmap and the deluxemap,
  per lightstyle; when off, exact legacy nearest-luxel behavior. Edits in
  ref/common/ref_light.c (cvar + helper + R_RecursiveLightPoint), ref_common.h
  (extern), ref_context.c (register). Builds clean (BUILD-AND-INSTALL-OK).
- Toggle/test at runtime: `r_lighting_filter 0` vs `1`. Needs a walking NPC to see;
  not yet visually verified by James. No menu toggle added (cvar only, as asked).
- All in the xash3d-fwgs repo (branch `streaming`); mainui untouched this time.

## 2026-06-16 — per-mod game-lib build loop (tools/dist/build-game-libs.sh)

- Key architecture fact: a GoldSrc game DLL is mod-specific game CODE, not an
  asset, and does NOT layer. Each game loads exactly one server + one client DLL
  (named by its gameinfo) and it must match the engine arch. No shared
  "continuum game DLL". So every custom-code mod needs its lib compiled from
  source. hlsdk-portable carries 58 reimplemented-source branches (opfor, bshift,
  theyhunger, poke646, sohl1.2, asheep, ...); `einar_amd64.so` etc. are built from
  these, NOT from the mods' shipped Windows .dll.
- Mod taxonomy: (1) asset/map-only mods run on valve's hl_<arch> lib — no build
  needed (dayone, uplink, darkstar); (2) mods with an hlsdk branch → checkout +
  build per target; (3) closed-source, no branch, Windows-.dll-only → no native
  Linux/macOS path (can't load PE, can't recompile); only a 32-bit WINDOWS engine
  can load their shipped .dll.
- NEW `tools/dist/build-game-libs.sh`: branch→install-dir manifest loop. For each
  entry: resolve ref (local/origin/upstream), `git checkout -f --detach` (avoids
  host worktree locks for bshift/opfor/theyhunger), `git clean -xdq`, read GAMEDIR
  from that branch's mod_options.txt, `waf configure $CONFIGURE_FLAGS && build &&
  install` to a temp destdir, copy dlls/+cl_dlls/ into $OUT/<install-dir>/.
  Idempotent skip (non-empty dlls dir) + FORCE=1. Manifest needs explicit install
  col because branch GAMEDIR != our folder (theyhunger builds "Hunger" → "hunger").
  Arch suffix (_amd64/_arm64/.dll/.dylib) baked in by hlsdk DEST_CPU.
- Wired into tools/dist/build-linux.sh (CONFIGURE_FLAGS="-T release $EXTRA", -8 on
  x86_64) and build-win32.sh (CONFIGURE_FLAGS="-T release", MinGW env; DEFERRED —
  future-commented). Replaced each container's old single-branch hlsdk build.
- Decision: 32-bit "max mod compat" is a WINDOWS-only benefit (load mods' shipped
  32-bit .dlls). On Linux mods ship no .so, so recompile-from-branch either way →
  Linux/macOS stay 64-bit. Initial release = linux-amd64 only (Steam Deck + amd64
  desktop). Long-term platforms: linux-amd64, linux-arm64, Windows (32-bit), macOS
  (needs a Mac or osxcross — the only real toolchain blocker; loop is unchanged).
- Bugs found + fixed when first run: (1) the build containers had NO `git` (old
  build never used it) — added `git` to Dockerfile.linux + Dockerfile.win32;
  (2) `git clean` needs `-f` (had dropped it over the rm-f rule) → `git clean -xdfq`;
  (3) added `git worktree prune` since the copied .git has stale worktree regs for
  bshift/opfor/theyhunger (host paths). hlsdk-portable is a submodule but its .git
  is a real DIR, so the tar-copy carries all refs/heads — fine once git is present.
- VERIFIED end-to-end in the linux-amd64 container: master->valve produced
  valve/dlls/hl_amd64.so + cl_dlls/client_amd64.so; a 2-mod run (master + theyhunger)
  confirmed branch-switching + the GAMEDIR≠install mapping (branch GAMEDIR "Hunger"
  -> installs to our "hunger"; server lib named einar_amd64.so), 64-bit x86-64.
- Host-run support: build-game-libs.sh now auto-detects container vs host — if
  /src/hlsdk-portable is absent it defaults SRC=./hlsdk-portable, OUT=./install
  (resolved from the script's own path), so `./tools/dist/build-game-libs.sh` runs
  from the repo root and installs straight into install/<gamedir>/ (FORCE=1 to
  overwrite existing libs). HLSDK stays a throwaway /tmp copy (it runs git clean).
  Verified on host: detects repo paths, skips already-built mods.
- All in xash3d-continuum repo, uncommitted.

## 2026-06-16 — game-libs build refactored to Python (catalog + selection list)

- Per James's Notes plan, replaced tools/dist/build-game-libs.sh with
  tools/dist/build-game-libs.py. Two modes:
  - `catalog`: scans every hlsdk-portable branch via `git show <ref>:mod_options.txt`
    (no checkouts — near-instant), reads GAMEDIR + SERVER_LIBRARY_NAME, writes
    tools/dist/game-libs-catalog.json mapping folder (lowercased GAMEDIR) -> branch
    + server. Default-branch pick per folder: prefer `master` (canonical valve —
    MANY mods declare GAMEDIR=valve), then branch==folder (bshift), then shortest
    (opfor over opforfixed); warns on collisions. 57 branches -> 40 folders.
  - `build` (default): reads tools/dist/game-libs.txt (one folder per line; `#`
    comments; `folder=branch` to override the catalog default), resolves each via
    the catalog, checkout --detach + clean + waf build + install into
    OUT/<folder>/{dlls,cl_dlls}. `--plan` prints folder->branch->build/skip without
    compiling. Keeps host/container auto-detect, throwaway HLSDK copy, arch-aware
    skip (*_amd64.so), FORCE. Env GAME_LIBS_CATALOG / GAME_LIBS_LIST override paths.
- Wired build-linux.sh + build-win32.sh to call `python3 .../build-game-libs.py`
  (python3 already in both Dockerfiles). Removed the .sh.
- VERIFIED on host: catalog gen (valve->master/hl, gearbox->opfor, bshift->bshift,
  hunger->theyhunger/einar), build --plan. VERIFIED in container: real Python build
  master->valve produced hl_amd64.so + client_amd64.so.
- Note: install/{valve,gearbox,bshift,hunger}/dlls now all HAVE their *_amd64.so
  (the pipeline populated them), so plan shows skip — correct.
- New committed-pending files: build-game-libs.py, game-libs.txt,
  game-libs-catalog.json. All uncommitted.

## 2026-06-16 — dist now bundles Uplink (playable out of the box)

- Distribution change: the package already bundles the engine, continuum/ assets,
  and game LIBS for valve/gearbox/bshift/hunger (libs only, user merges assets).
  ADDED: Half-Life: Uplink — Valve's free, redistributable demo — bundled FULLY so
  Continuum is playable with no user content. Uplink is self-contained (pak0.PAK,
  ~77 MB) and runs vanilla HL code, so it reuses valve's master-built lib.
- `tools/build_all.sh`: new `stage_uplink()` (host-side, called from build_linux
  after stage_assets). Copies install/uplink content via tar minus per-user state
  (config.cfg*, opengl/video.cfg*, .xash_id, vfs.cfg, cache/, save/, .fontcache/),
  platform binaries (dlls/, cl_dlls/ — Windows .dll), and the Continuum runtime
  menu-cache (gfx/shell/continuum). Then copies $out/valve/{dlls,cl_dlls}/*.so into
  uplink (arch suffix already in name). UPLINK_SRC env overrides the source.
- README-DIST.md updated: no longer "no game content" — now ships the free Uplink
  demo; "Play right now: ./xash3d.sh -game uplink"; full games still user-supplied
  (drop valve/expansion folders, merge; their game code is already bundled).
- CAVEAT (flagged, not yet solved): uplink source is install/uplink, which is
  GITIGNORED ("copyrighted HL assets — never distribute"; uplink is the legal
  exception). So a clean clone / CI can't build the bundle. Follow-up: move uplink
  redist content to a committed location (Git LFS for the ~79 MB pak) or fetch it.
- Out-of-box UX gap (flagged): xash3d.sh defaults to -game valve (empty until the
  user adds it), so double-click isn't immediately playable — you must pass
  -game uplink. Possible follow-up: default the launcher to uplink when valve has
  no maps.
- VERIFIED: bash -n; stage_uplink include/exclude + lib-copy tested in isolation
  (pak0/liblist/libs present; config/cache/.xash_id/win-dlls/menu-cache excluded).
  NOT yet run as a full `build_all.sh linux-amd64` (long: engine + 4 hlsdk builds).
- All uncommitted.

## 2026-06-16 — redist/ folder: committed source-of-truth for bundled content

- New top-level `redist/` collects the static content that ships in dist packages,
  decoupling it from the gitignored `install/` runtime area:
  - `redist/continuum/` — COMMITTED. Continuum's own assets (fonts, controller
    glyphs, brand-mark pngs), copied from install/continuum MINUS the runtime-
    generated per-game backgrounds (gfx/shell/continuum/games). 51 files. Always
    bundled.
  - `redist/uplink/` — GITIGNORED, optional. User drops the uplink folder here to
    have it bundled; absent = package ships without it.
  - `redist/README.md` (committed) explains the convention; `redist/.gitignore`
    uses `/*` + `!continuum` + `!README.md` so only continuum/ + docs are tracked.
- build_all.sh: stage_assets now `cp -a redist/continuum/. $out/continuum/`
  (replaced the curated cp list). stage_uplink UPLINK_SRC default is now
  redist/uplink (was install/uplink); to use the existing copy without moving:
  UPLINK_SRC=install/uplink, or `cp -a install/uplink redist/uplink`.
- Launcher tools/dist/xash3d.sh: out-of-the-box default-to-uplink. If the user
  passed no -game AND valve has no maps (no valve/maps/*.bsp, no valve/pak0.pak)
  AND uplink/liblist.gam exists -> injects `-game uplink`. Once valve assets are
  added, falls back to engine default (valve). README-DIST "Play right now" now
  says just run ./xash3d.sh. (Windows .exe has no wrapper, so it still needs
  -game uplink — Windows deferred anyway.)
- ACTION for James: to actually bundle uplink, place it at redist/uplink
  (cp/mv from install/uplink) or build with UPLINK_SRC=install/uplink.
- Verified: bash -n/sh -n; redist/.gitignore (uplink ignored, continuum tracked);
  stage_assets copy (51 files, no games/); launcher logic (3 cases: inject /
  valve-present / explicit -game).

## 2026-06-16 — dogfood dev loop: run from dist-test/, install→game-reference

- James renamed install/ -> game-reference/ (gitignored; reference assets only,
  for looking at gamefiles). New dev/test loop runs the ACTUAL dist package.
- Distribution model (confirmed): build BOTH engine + game libs in the container
  (-> /out), then copy redist/ ON TOP (continuum + uplink). That's already what
  build_all does (stage_assets<-redist/continuum, stage_uplink<-redist/uplink,
  libs built in-container). So NO change to build_all's lib architecture — redist
  is the static overlay only, NOT where libs go. (Earlier "libs -> redist" idea
  was retracted by James.)
- NEW tools/dogfood.sh: `build_all linux-amd64` -> extract artifact into dist-test/
  with `tar --strip-components=1` (package contents land directly in dist-test/),
  WITHOUT clearing (a valve/ you drop there persists; package libs merge on top) ->
  exec dist-test/xash3d.sh. `--no-run` to skip launch. Verified extract+merge.
- Repointed local tooling install/ -> dist-test/:
  - build-engine.sh: `--destdir=$ROOT/dist-test` (fast engine refresh over the
    dogfood tree).
  - build-game-libs.py: host OUT default now <repo>/dist-test (was install) — for
    fast single-lib iteration into the run dir. Container path unchanged (OUT=/out).
  - play-continuum.sh: cd dist-test (errors if absent -> run dogfood.sh).
  - capture-demo.sh, capture-menu-gif.sh: all install/ -> dist-test/.
  - clear-ao-cache.sh: default roots dist-test/*.
  - build-flatpak.sh icon: install/continuum -> redist/continuum.
- .gitignore already has game-reference/ + dist-test/ (James added). install/ line
  is now stale but harmless.
- Verified: bash -n / py_compile on all touched scripts; dogfood extract/merge.
  NOT run full (Docker) end-to-end. All uncommitted.

## 2026-06-16 — menu localization shipped in continuum/; uplink copy was incomplete

- Menu showed raw tokens (GameUI_OK/GameUI_Cancel) without a user valve. Root: the
  Continuum mainui uses 79 GameUI_* tokens, ALL defined only in valve/resource/
  gameui_english.txt (loaded via Localize_AddToDictionary from the search path).
  StringsList_* are mainui-built-in (fine); only GameUI_* broke.
- FIX (Approach A, done): authored redist/continuum/resource/gameui_english.txt —
  Continuum's own generic UI labels for all 79 GameUI_* tokens. continuum/ is
  always-mounted (lowest priority) so the menu reads correctly for EVERY game even
  before a user valve; a real valve/resource overrides it. Policy-clean (generic
  labels, not copied from Valve). stage_assets already copies redist/continuum/. so
  it bundles automatically. Verified all 79 covered; live in dist-test.
- SEPARATE issue — "New Game bounces back to menu": NOT localization. hldemo1
  precaches base HL assets missing from the user's uplink pak0 (e.g. models/
  w_357.mdl — fatal Host_Error on a missing precached model; also MP HUD sprites
  iplayer*.spr, 357/crossbow/egon/squeak sounds). Cause: the user's uplink is a
  STRIPPED copy that leaned on a co-installed valve (it has w_357t.mdl/w_357ammot.mdl
  but not base w_357.mdl), run against the FULL HL game/client libs (master) which
  precache the complete arsenal. James confirmed, and is downloading the complete
  free-CD Uplink ISO. Once placed at redist/uplink (replacing the stripped copy) +
  re-dogfood, the precache abort should be gone. NOT a build/script bug — incomplete
  game content. (delta.lst we added earlier stays; the complete demo will have it too.)
- All uncommitted.

## 2026-06-16 — ABANDONED: bundling Uplink / out-of-the-box playable

- Decision (James): drop the whole "ship Uplink so Continuum is playable out of the
  box" idea. Why: the authentic free-CD Uplink DEMO ships its own valve folder whose
  demo-era assets would BREAK the other games; and James's uplink MOD copy is edited
  to match a RETAIL valve, so it only works AS A MOD on top of a user's valve — i.e.
  no standalone/out-of-box value either way. (Supersedes the earlier "dist bundles
  Uplink" + "delta.lst in uplink" + out-of-box-launcher entries above.)
- Reverted: build_all.sh stage_uplink() removed (+ its call); tools/dist/xash3d.sh
  back to plain launcher (no default-to-uplink); play-continuum.sh back to GAME=valve
  default; README-DIST.md back to "no game content — you supply the games";
  redist/README.md says continuum/ is the only bundled content and anything else
  dropped in redist/ (valve, uplink, ...) is gitignored + NOT bundled.
- Package is now: engine + continuum/ overlay + per-mod game libs; user supplies
  valve + any games/mods. KEPT (independent, good): redist/continuum/resource/
  gameui_english.txt (the 79-token menu localization, all games).
- Leftover gitignored cruft James can delete: redist/uplink/ and dist-test/uplink/
  (incl. the delta.lst I'd added for the abandoned standalone attempt). Harmless.

## 2026-06-16 — Elefant embedder outage

- Elefant MCP unreachable this session: `search`, `memory_search`, `memory_list`,
  etc. all return HTTP 403 Forbidden from `http://embedder:8001`. Could not consult
  or write Elefant memories. (Transient infra issue — note for the replay, not a
  durable fact about the project.)
