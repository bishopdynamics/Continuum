#!/usr/bin/env python3
"""Build per-mod game libraries (server + client) from hlsdk-portable branches.

Two-stage design:

  catalog   Scan every hlsdk-portable branch, read GAMEDIR + SERVER_LIBRARY_NAME
            from each branch's mod_options.txt, and write a branch->folder
            catalog (game-libs-catalog.json). foldername = GAMEDIR lowercased.
            Reads each branch's file with `git show <ref>:mod_options.txt`, so no
            checkouts are needed — regeneration is near-instant. Run when you add
            or track new branches; commit the JSON.

  build     (default) Read the selection list (game-libs.txt) of foldernames to
            build, look each up in the catalog, then checkout + build + install
            into <OUT>/<folder>/{dlls,cl_dlls}/. Add --plan to print the
            folder->branch->build/skip decisions without compiling.

WHY per-branch: a GoldSrc game DLL is mod-specific game *code*, not an asset; it
does NOT layer. Each game loads exactly one server + one client DLL, named by its
gameinfo, matching the engine arch. So every custom-code mod is compiled from its
own hlsdk-portable branch. (Asset/map-only mods that declare vanilla HL code need
no entry — they run on valve's hl_<arch> lib.)

Runs both INSIDE the build container (OUT=/out, the package staging tree) and
directly from a host checkout for fast single-lib iteration — on the host it
installs into ./dist-test/<game>/ (the dogfood run dir, alongside the engine),
so a rebuilt lib lands exactly where you run it.

Env (all optional):
  SRC       hlsdk-portable source w/ .git   (default: /src or <repo>/hlsdk-portable)
  OUT       game-dirs root                  (default: /out or <repo>/dist-test)
  HLSDK     throwaway build copy            (default: /tmp/b/hlsdk — NOT your tree)
  CONFIGURE_FLAGS="-T release -8"  target select (container sets this per-arch)
  FORCE=0                          1 = rebuild even if this arch's lib exists
"""
import json
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
from glob import glob
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent          # tools/dist
REPO = SCRIPT_DIR.parent.parent                       # repo root
CATALOG = Path(os.environ.get("GAME_LIBS_CATALOG") or SCRIPT_DIR / "game-libs-catalog.json")
SELECTION = Path(os.environ.get("GAME_LIBS_LIST") or SCRIPT_DIR / "game-libs.txt")

IN_CONTAINER = Path("/src/hlsdk-portable").is_dir()
SRC = Path(os.environ.get("SRC") or ("/src/hlsdk-portable" if IN_CONTAINER else REPO / "hlsdk-portable"))
OUT = Path(os.environ.get("OUT") or ("/out" if IN_CONTAINER else REPO / "dist-test"))
HLSDK = Path(os.environ.get("HLSDK") or "/tmp/b/hlsdk")
# Linux/win containers set this explicitly per-target. The default serves a bare
# host run: macOS builds for its native arch (no -8; arm64 DEST_CPU is auto),
# Linux defaults to 64-bit.
_DEFAULT_FLAGS = "-T release" if platform.system() == "Darwin" else "-T release -8"
CONFIGURE_FLAGS = os.environ.get("CONFIGURE_FLAGS", _DEFAULT_FLAGS)
FORCE = os.environ.get("FORCE", "0") == "1"

# Linux lib suffix this target produces (hl_amd64.so / hl_arm64.so), used for the
# "already built" check. Cross targets (win32 .dll, macOS .dylib) won't match, so
# they always rebuild — harmless, dist builds start from an empty OUT.
_MACH = platform.machine()
LIBSUF = {"x86_64": "_amd64.so", "aarch64": "_arm64.so", "arm64": "_arm64.so"}.get(_MACH, f"_{_MACH}.so")


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def git(repo, *args, check=True):
    """Run git in `repo`, returning stdout (stripped). check=False tolerates failure."""
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        die(f"git {' '.join(args)} failed:\n{r.stderr.strip()}")
    return r.stdout.strip() if r.returncode == 0 else None


def resolve_ref(repo, branch):
    """A real ref for `branch`: prefer local, then origin/, then upstream/."""
    for r in (branch, f"origin/{branch}", f"upstream/{branch}"):
        if git(repo, "rev-parse", "--verify", "-q", r, check=False) is not None:
            return r
    return None


def read_mod_options(repo, ref):
    """Return (gamedir, server) from <ref>:mod_options.txt, or None if absent."""
    text = git(repo, "show", f"{ref}:mod_options.txt", check=False)
    if text is None:
        return None
    gamedir = server = None
    for line in text.splitlines():
        line = line.strip()
        for key in ("GAMEDIR=", "SERVER_LIBRARY_NAME="):
            if line.startswith(key):
                val = line[len(key):].split("#", 1)[0].strip()
                if key == "GAMEDIR=":
                    gamedir = val
                else:
                    server = val
    return (gamedir, server) if gamedir else None


def ensure_hlsdk_copy():
    """One-time independent clone of hlsdk-portable so we can checkout/build any
    branch without touching SRC (which may be read-only). Reused across runs.

    A `git clone --local` (not a raw tar copy) so this works whether SRC's .git
    is an absorbed directory OR a gitlink FILE — the latter is what a fresh
    `git clone --recursive` produces for a submodule, and its relative
    "gitdir: ../.git/modules/..." pointer breaks under a plain copy."""
    if (HLSDK / ".git").exists():
        return
    HLSDK.parent.mkdir(parents=True, exist_ok=True)
    # --local: no network, objects hardlinked/copied from SRC. --no-checkout:
    # _build_one checks out a detached ref per game anyway.
    subprocess.check_call(["git", "clone", "--local", "--no-checkout", str(SRC), str(HLSDK)])
    # clone only brings SRC's local heads; the per-mod branches we build live in
    # SRC's remote-tracking refs (origin/master, origin/opfor, ...) — copy those.
    subprocess.check_call(["git", "-C", str(HLSDK), "fetch", "--no-tags", str(SRC),
                           "+refs/remotes/origin/*:refs/remotes/origin/*"])
    subprocess.run(["git", "-C", str(HLSDK), "config", "--add", "safe.directory", str(HLSDK)])


# --------------------------------------------------------------------------- #
def cmd_catalog():
    """Scan all branches and (re)write game-libs-catalog.json."""
    # read-only: scan refs straight from SRC, no writable copy / checkouts needed.
    repo = SRC
    subprocess.run(["git", "-C", str(repo), "config", "--add", "safe.directory", str(repo)])
    refs = git(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes") or ""

    names = set()
    for n in refs.split():
        for pre in ("origin/", "upstream/"):
            if n.startswith(pre):
                n = n[len(pre):]
        if n in ("", "HEAD", "origin", "upstream") or n.endswith("/HEAD"):
            continue
        names.add(n)

    catalog = {}
    for name in sorted(names):
        ref = resolve_ref(repo, name)
        if not ref:
            continue
        mo = read_mod_options(repo, ref)
        if not mo:
            continue
        gamedir, server = mo
        folder = gamedir.lower()
        catalog.setdefault(folder, {"candidates": []})["candidates"].append(
            {"branch": name, "server": server}
        )

    # pick a default branch per folder: 'master' (the canonical base game, for the
    # many mods that also declare GAMEDIR=valve) first, then a branch whose name
    # matches the folder (bshift->bshift), then the shortest name (opfor over
    # opforfixed), tie-break alphabetical. Warn on collisions.
    out = {}
    for folder in sorted(catalog):
        def rank(c, _f=folder):
            b = c["branch"]
            return (b != "master", b != _f, len(b), b)
        cands = sorted(catalog[folder]["candidates"], key=rank)
        default = cands[0]
        out[folder] = {"branch": default["branch"], "server": default["server"]}
        if len(cands) > 1:
            out[folder]["candidates"] = [c["branch"] for c in cands]
            others = ", ".join(c["branch"] for c in cands[1:])
            print(f"  note: folder '{folder}' -> default '{default['branch']}' "
                  f"(also: {others}; override in {SELECTION.name})", file=sys.stderr)

    CATALOG.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(f"scanned {len(names)} branches -> {CATALOG} ({len(out)} game folders)")


# --------------------------------------------------------------------------- #
def parse_selection():
    """Yield (folder, branch_override_or_None) from game-libs.txt."""
    if not SELECTION.exists():
        die(f"no selection file {SELECTION} (one folder per line; 'folder=branch' to override)")
    for raw in SELECTION.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if "=" in line:
            folder, branch = (x.strip() for x in line.split("=", 1))
            yield folder, branch
        else:
            yield line, None


def cmd_build(plan_only):
    catalog = json.loads(CATALOG.read_text()) if CATALOG.exists() else {}
    if not catalog and not plan_only:
        die(f"no catalog {CATALOG.name} — run `{Path(__file__).name} catalog` first")

    selections = list(parse_selection())
    repo = SRC if plan_only else HLSDK
    if not plan_only:
        ensure_hlsdk_copy()

    for folder, override in selections:
        branch = override or catalog.get(folder, {}).get("branch")
        if not branch:
            die(f"folder '{folder}' not in catalog and no override — "
                f"add 'catalog' entry or write '{folder}=<branch>' in {SELECTION.name}")

        target = OUT / folder
        already = bool(glob(str(target / "dlls" / f"*{LIBSUF}")))
        action = "skip" if (already and not FORCE) else "build"
        ref = resolve_ref(repo, branch)
        print(f"  {folder:<14} <- {branch:<16} [{ref or 'NO REF'}]  {action}")

        if plan_only:
            if not ref:
                print(f"      ! branch '{branch}' has no ref (local/origin/upstream)", file=sys.stderr)
            continue
        if action == "skip":
            continue
        if not ref:
            die(f"no ref for branch '{branch}' (local/origin/upstream)")

        _build_one(branch, ref, folder, target)

    if plan_only:
        print("(--plan: nothing built)")


def _build_one(branch, ref, folder, target):
    git(HLSDK, "checkout", "-f", "--detach", ref)
    git(HLSDK, "clean", "-xdfq")

    mo = read_mod_options(HLSDK, "HEAD")
    if not mo:
        die(f"branch '{branch}' has no GAMEDIR in mod_options.txt")
    src_gamedir = mo[0]  # original case, e.g. 'Hunger' — the build installs here

    dest = Path(tempfile.mkdtemp(prefix="glib-"))
    log = subprocess.run(
        f'./waf configure {CONFIGURE_FLAGS} && ./waf build && ./waf install --destdir="{dest}"',
        shell=True, cwd=HLSDK, capture_output=True, text=True,
    )
    if log.returncode != 0:
        print(f"  BUILD FAILED ({branch}) — last lines:", file=sys.stderr)
        print("\n".join((log.stdout + log.stderr).splitlines()[-20:]), file=sys.stderr)
        shutil.rmtree(dest, ignore_errors=True)
        sys.exit(1)

    copied = 0
    for sub in ("dlls", "cl_dlls"):
        srcdir = dest / src_gamedir / sub
        if not srcdir.is_dir():
            continue
        (target / sub).mkdir(parents=True, exist_ok=True)
        for f in srcdir.iterdir():
            if f.is_file():
                shutil.copy2(f, target / sub / f.name)
                copied += 1
    shutil.rmtree(dest, ignore_errors=True)
    print(f"      -> {target}/{{dlls,cl_dlls}} ({copied} files)")


# --------------------------------------------------------------------------- #
def main():
    args = sys.argv[1:]
    plan = "--plan" in args
    mode = next((a for a in args if not a.startswith("-")), "build")
    if mode == "catalog":
        cmd_catalog()
    elif mode == "build":
        cmd_build(plan_only=plan)
    else:
        die(f"unknown mode '{mode}' (use: catalog | build [--plan])")


if __name__ == "__main__":
    main()
