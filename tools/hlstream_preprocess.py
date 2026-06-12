#!/usr/bin/env python3
"""hlstream preprocessor (M1 prototype).

Derives streaming metadata from the user's own Half-Life maps — we ship this code,
never the derived data (see docs/research/00-scope-and-constraints.md).

Input:  a maps/ directory of GoldSrc BSPs (v30)
Output: JSON map graph: nodes (map, size, entity count, world bounds),
        edges (landmark transforms, flags), anomaly/quirk report.

Usage: hlstream_preprocess.py <maps_dir> [-o out.json] [--campaign-only]
"""
import argparse
import json
import re
import struct
import sys
from pathlib import Path

BSP_VERSION = 30
LUMP_ENTITIES = 0
LUMP_PLANES = 1
LUMP_MODELS = 14
NUM_LUMPS = 15
DMODEL_SIZE = 64  # float mins[3], maxs[3], origin[3]; int headnode[4], visleafs, firstface, numfaces

CAMPAIGN_RE = re.compile(r"^c[0-5]a")


def read_bsp(path):
    """Return (entity_lump_text, world_bounds) for a v30 BSP."""
    with open(path, "rb") as f:
        (version,) = struct.unpack("<i", f.read(4))
        if version != BSP_VERSION:
            raise ValueError(f"{path.name}: unsupported BSP version {version}")
        lumps = [struct.unpack("<ii", f.read(8)) for _ in range(NUM_LUMPS)]

        off, ln = lumps[LUMP_ENTITIES]
        f.seek(off)
        ents = f.read(ln).split(b"\0", 1)[0].decode("latin1")
        if "classname" not in ents:
            # Blue Shift BSP variant: entities and planes lumps are swapped
            off, ln = lumps[LUMP_PLANES]
            f.seek(off)
            ents = f.read(ln).split(b"\0", 1)[0].decode("latin1")

        off, ln = lumps[LUMP_MODELS]
        f.seek(off)
        m = struct.unpack("<9f", f.read(DMODEL_SIZE)[:36])  # model 0 = worldspawn: mins, maxs, origin
        bounds = (list(m[0:3]), list(m[3:6]))
    return ents, bounds


def parse_entities(text):
    """Entity lump text -> list of key/value dicts (last key wins, GoldSrc style)."""
    out = []
    for block in re.findall(r"\{[^}]*\}", text, re.S):
        kv = dict(re.findall(r'"([^"]*)"\s+"([^"]*)"', block))
        if kv:
            out.append(kv)
    return out


def vec(s):
    try:
        return [float(x) for x in s.split()]
    except ValueError:
        return [0.0, 0.0, 0.0]


def build_graph(maps_dir, campaign_only):
    nodes = {}
    triggers = []  # (from_map, to_map, landmark, use_only)

    for path in sorted(maps_dir.glob("*.bsp")):
        name = path.stem.lower()
        if campaign_only and not CAMPAIGN_RE.match(name):
            continue
        try:
            ents_text, bounds = read_bsp(path)
        except ValueError as e:
            print(f"skip: {e}", file=sys.stderr)
            continue
        ents = parse_entities(ents_text)

        landmarks = {}
        for e in ents:
            if e.get("classname") == "info_landmark" and "targetname" in e:
                landmarks[e["targetname"]] = vec(e.get("origin", "0 0 0"))

        n_trans = 0
        for e in ents:
            if e.get("classname") == "trigger_changelevel" and e.get("map"):
                use_only = bool(int(e.get("spawnflags", "0")) & 2)
                triggers.append((name, e["map"].lower(), e.get("landmark", ""), use_only))
                n_trans += 1

        nodes[name] = {
            "size_bytes": path.stat().st_size,
            "entity_count": len(ents),
            "world_mins": bounds[0],
            "world_maxs": bounds[1],
            "landmarks": landmarks,
            "transition_volumes": sorted(
                {e.get("targetname", "") for e in ents if e.get("classname") == "trigger_transition"} - {""}
            ),
            "num_changelevels": n_trans,
        }
    return nodes, triggers


def build_edges(nodes, triggers):
    """Pair directed triggers into undirected edges with per-landmark transforms."""
    edges = {}
    anomalies = []

    for src, dst, lm, use_only in triggers:
        if dst not in nodes:
            anomalies.append({"type": "target_map_missing", "map": src, "target": dst})
            continue
        key = tuple(sorted((src, dst)))
        e = edges.setdefault(key, {"a": key[0], "b": key[1], "links": []})

        src_pos = nodes[src]["landmarks"].get(lm)
        dst_pos = nodes[dst]["landmarks"].get(lm)
        if lm and src_pos is None:
            anomalies.append({"type": "landmark_missing_in_source", "map": src, "target": dst, "landmark": lm})
        if lm and dst_pos is None:
            anomalies.append({"type": "landmark_missing_in_target", "map": src, "target": dst, "landmark": lm})

        # transform: position of B's frame relative to A's (apply to B to place it in A)
        offset_in_a = None
        if src_pos is not None and dst_pos is not None:
            a_pos = src_pos if key[0] == src else dst_pos
            b_pos = dst_pos if key[0] == src else src_pos
            offset_in_a = [round(a - b, 3) for a, b in zip(a_pos, b_pos)]

        link = {"from": src, "to": dst, "landmark": lm, "use_only": use_only, "b_to_a_offset": offset_in_a}
        if link not in e["links"]:
            e["links"].append(link)

    # classify edges
    for e in edges.values():
        offsets = {tuple(l["b_to_a_offset"]) for l in e["links"] if l["b_to_a_offset"] is not None}
        e["transform_count"] = len(offsets)
        e["consistent"] = len(offsets) == 1
        e["walkthrough"] = any(not l["use_only"] for l in e["links"])
        e["zero_offset"] = offsets == {(0.0, 0.0, 0.0)}
        if len(offsets) > 1:
            anomalies.append({
                "type": "inconsistent_parallel_transforms",
                "edge": f"{e['a']}<->{e['b']}",
                "offsets": sorted(offsets),
            })
        e["stitch_candidate"] = e["consistent"] and e["walkthrough"]

    return sorted(edges.values(), key=lambda x: (x["a"], x["b"])), anomalies


def preload_order(nodes, edges):
    """Campaign maps in BFS order from the alphabetically-first connected map,
    so the maps nearest the campaign start are warmed first."""
    adj = {}
    for e in edges:
        adj.setdefault(e["a"], set()).add(e["b"])
        adj.setdefault(e["b"], set()).add(e["a"])

    order, seen = [], set()
    for root in sorted(adj):
        if root in seen:
            continue
        queue = [root]
        seen.add(root)
        while queue:
            m = queue.pop(0)
            order.append(m)
            for n in sorted(adj.get(m, ())):
                if n not in seen and n in nodes:
                    seen.add(n)
                    queue.append(n)
    return order


def write_preload_cfg(path, order):
    lines = [
        "// generated by hlstream_preprocess.py from your own game data — do not distribute",
        "// preloads the campaign worlds into the engine residency cache, one map per frame",
    ]
    for m in order:
        lines.append(f"world_preload {m}")
        lines.append("wait")
    path.write_text("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("maps_dir", type=Path,
                    help="maps directory of BSPs, or an existing mapgraph .json "
                         "(for games whose maps live inside pak archives)")
    ap.add_argument("-o", "--out", type=Path, default=Path("mapgraph.json"))
    ap.add_argument("--campaign-only", action="store_true")
    ap.add_argument("--preload-cfg", type=Path, default=None,
                    help="also write a streampreload cfg (world_preload per connected campaign map)")
    args = ap.parse_args()

    if args.maps_dir.suffix == ".json":
        # reuse a previously-built graph (BSPs may be inside paks)
        g = json.loads(args.maps_dir.read_text())
        if args.preload_cfg:
            order = preload_order(g["maps"], g["edges"])
            write_preload_cfg(args.preload_cfg, order)
            print(f"wrote {args.preload_cfg} ({len(order)} maps) from {args.maps_dir}")
        return

    nodes, triggers = build_graph(args.maps_dir, args.campaign_only)
    edges, anomalies = build_edges(nodes, triggers)

    deg = {}
    for e in edges:
        deg[e["a"]] = deg.get(e["a"], 0) + 1
        deg[e["b"]] = deg.get(e["b"], 0) + 1

    result = {
        "maps": nodes,
        "edges": edges,
        "anomalies": anomalies,
        "stats": {
            "num_maps": len(nodes),
            "num_changelevel_triggers": len(triggers),
            "num_edges": len(edges),
            "num_stitch_candidates": sum(e["stitch_candidate"] for e in edges),
            "num_use_only_edges": sum(not e["walkthrough"] for e in edges),
            "hubs_3plus": sorted([m for m, d in deg.items() if d >= 3]),
            "max_degree": max(deg.values()) if deg else 0,
        },
    }
    args.out.write_text(json.dumps(result, indent=1))

    if args.preload_cfg:
        order = preload_order(nodes, edges)
        write_preload_cfg(args.preload_cfg, order)
        print(f"wrote {args.preload_cfg} ({len(order)} maps)")

    s = result["stats"]
    print(f"maps: {s['num_maps']}  triggers: {s['num_changelevel_triggers']}  edges: {s['num_edges']}")
    print(f"stitch candidates: {s['num_stitch_candidates']}  use-only edges: {s['num_use_only_edges']}")
    print(f"hubs (deg>=3): {', '.join(s['hubs_3plus'])}")
    print(f"anomalies: {len(anomalies)}")
    for a in anomalies:
        print("  ", a)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
