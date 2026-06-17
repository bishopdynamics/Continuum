#!/usr/bin/env python3
"""
Lint a Continuum menu-tour script (menu-tours/<name>.txt) before running it.

The engine's tour interpreter (xash3d-fwgs/3rdparty/mainui/menus/continuum/Tour.cpp)
silently skips lines it can't parse, so a typo like `key ESC` or `ponder ...` just
does nothing. This pre-check catches those up front. It owns *correctness*; the
engine only traces what it actually does at runtime.

Grammar (must match Tour.cpp):
    # comment                     full-line or inline (first unquoted '#')
    wait <ms>                     non-negative integer
    click "<label>"               on-screen button text (quotes recommended)
    focus "<label>"               same, but don't activate
    key <name>                    up|down|left|right|enter|escape|back|tab|pgup|pgdn
    back                          (no args)
    mark <label>                  rec_start / rec_stop bracket the GIF recording
    inhibit_settings              (no args) force the clean-capture settings (overlay off)
    restore_settings              (no args) put them back — call AFTER mark rec_stop
    open_menu                     (no args) open the menu (e.g. over a running game)
    close_menu                    (no args) dismiss the menu back to the game

Exit status: 0 if clean (warnings allowed), 1 if any error (or any warning with
--strict), 2 on usage error.

Usage:
    tools/lint-menu-tour.py menu-tours/menu-tour.txt [more.txt ...] [--strict]
"""
import sys

VERBS = {"wait", "click", "focus", "key", "back", "mark",
         "inhibit_settings", "restore_settings", "open_menu", "close_menu"}
NOARG = {"back", "inhibit_settings", "restore_settings", "open_menu", "close_menu"}
KEYS = {"up", "down", "left", "right", "enter", "escape", "back", "tab", "pgup", "pgdn"}


def strip_comment(line):
    """Truncate at the first '#' that isn't inside a double-quoted string."""
    inq = False
    for i, ch in enumerate(line):
        if ch == '"':
            inq = not inq
        elif ch == "#" and not inq:
            return line[:i]
    return line


def read_label(rest):
    """Return (label, quoted, error). Mirrors Tour_ReadLabel + quote checking."""
    rest = rest.strip()
    if rest.startswith('"'):
        end = rest.find('"', 1)
        if end < 0:
            return ("", True, "unterminated quote")
        return (rest[1:end], True, None)
    return (rest, False, None)


def lint_file(path, strict=False):
    errors, warnings = [], []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            raw = fh.readlines()
    except OSError as exc:
        return [f"{path}: cannot read: {exc}"], []

    have_start = have_stop = False
    have_inhibit = have_restore = False

    for n, line in enumerate(raw, 1):
        body = strip_comment(line).strip()
        if not body:
            continue

        parts = body.split(None, 1)
        verb = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ""

        def err(msg):
            errors.append(f"{path}:{n}: error: {msg}")

        def warn(msg):
            warnings.append(f"{path}:{n}: warning: {msg}")

        if verb not in VERBS:
            err(f"unknown verb: {parts[0]}")
            continue

        if verb == "wait":
            if not rest.strip().isdigit():
                err(f"wait needs a non-negative integer (ms), got: {rest.strip() or '<nothing>'}")

        elif verb in ("click", "focus"):
            label, quoted, lerr = read_label(rest)
            if lerr:
                err(lerr)
            elif not label:
                err(f"{verb} needs a button label, e.g. {verb} \"New Game\"")
            elif not quoted:
                warn(f"{verb} label is unquoted; quote it to be safe: {verb} \"{label}\"")

        elif verb == "key":
            tokens = rest.split()
            if not tokens:
                err("key needs a name: up|down|left|right|enter|escape|back|tab|pgup|pgdn")
            else:
                name = tokens[0].lower()
                if name not in KEYS:
                    err(f"unknown key: {tokens[0]} (use up|down|left|right|enter|escape|back|tab|pgup|pgdn)")
                if len(tokens) > 1:
                    warn(f"extra text after key: {' '.join(tokens[1:])}")

        elif verb in NOARG:
            if rest.strip():
                warn(f"{verb} takes no arguments; ignoring: {rest.strip()}")
            if verb == "inhibit_settings":
                have_inhibit = True
            elif verb == "restore_settings":
                have_restore = True

        elif verb == "mark":
            tokens = rest.split()
            if not tokens:
                err("mark needs a label, e.g. mark rec_start")
            else:
                label = tokens[0]
                if label == "rec_start":
                    have_start = True
                elif label == "rec_stop":
                    have_stop = True
                if len(tokens) > 1:
                    warn(f"extra text after mark; only the first word is the label: {' '.join(tokens[1:])}")

    if not have_start:
        errors.append(f"{path}: error: no 'mark rec_start' — the capture wrapper needs it to start recording")
    if not have_stop:
        warnings.append(f"{path}: warning: no 'mark rec_stop' — recording will stop on the engine's DONE instead")
    if have_inhibit and not have_restore:
        warnings.append(f"{path}: warning: 'inhibit_settings' without 'restore_settings' — settings stay inhibited until the tour ends")

    return errors, warnings


def main(argv):
    args = [a for a in argv[1:] if a != "--strict"]
    strict = "--strict" in argv[1:]
    if not args:
        sys.stderr.write("usage: lint-menu-tour.py <tour.txt> [more.txt ...] [--strict]\n")
        return 2

    total_err = total_warn = 0
    for path in args:
        errors, warnings = lint_file(path, strict)
        for w in warnings:
            print(w)
        for e in errors:
            print(e)
        total_err += len(errors)
        total_warn += len(warnings)

    if total_err:
        print(f"FAIL: {total_err} error(s), {total_warn} warning(s)")
        return 1
    if total_warn and strict:
        print(f"FAIL (strict): {total_warn} warning(s)")
        return 1
    print(f"OK: {total_warn} warning(s)" if total_warn else "OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
