#!/usr/bin/env python3
"""Convertit data/yopougon_siporex_ficgayo.json (produit par tools/build_yopougon_map.py, schema_version 1)
en un JSON plat lisible par JsonUtility de Unity (pas de tableaux imbriqués, pas de dictionnaires).

Repère de sortie (Unity) : x = est (m), z = nord (m), y = haut. Le script d'origine écrit z = -(lat-lat0)*111320
(convention Godot, nord = -z) : on inverse donc z. Les identifiants OSM et les tags utiles sont conservés.

Usage :
  python3 tools/osm_to_unity.py data/yopougon_siporex_ficgayo.json \
      UnityProject/Assets/Nightfall/Resources/Data/yopougon_unity.json
Les hauteurs absentes d'OSM sont ESTIMEES (height_estimated = true) : ne pas les présenter comme des mesures.
"""
import json, math, sys

SIPOREX = (5.35417, -4.07457)   # docs/YOPOUGON_SIPOREX_FICGAYO.md
FICGAYO = (5.34859, -4.07196)

ROAD_WIDTH = {"motorway": 14, "trunk": 14, "primary": 12, "secondary": 10, "tertiary": 8, "residential": 6,
              "unclassified": 6, "service": 4, "living_street": 5, "track": 3, "path": 2, "footway": 2, "pedestrian": 4}


def flat(path):
    out = []
    for x, z in path:
        out.append(round(x, 2)); out.append(round(-z, 2))   # inversion de z (nord = +z)
    return out


def local(lat, lon, lat0, lon0):
    x = (lon - lon0) * 111320.0 * math.cos(math.radians(lat0))
    z = (lat - lat0) * 111320.0
    return round(x, 2), round(z, 2)


def convert(src):
    if src.get("schema_version") != 1:
        raise SystemExit("schema_version inattendu : %r" % src.get("schema_version"))
    lat0, lon0 = src["origin"]["lat"], src["origin"]["lon"]
    buildings, roads, places = [], [], []
    for b in src.get("buildings", []):
        fp = b.get("footprint", [])
        if len(fp) < 4:
            continue
        tags = b.get("tags", {})
        buildings.append({
            "osm_id": b["osm_id"],
            "kind": tags.get("building", "yes"),
            "name": tags.get("name", ""),
            "levels": b.get("levels") or 0,
            "height_m": b.get("height_m") or 0.0,
            "height_estimated": bool(b.get("height_is_estimated", False)),
            "pts": flat(fp[:-1] if fp[0] == fp[-1] else fp),
        })
    for r in src.get("roads", []):
        tags = r.get("tags", {})
        hw = tags.get("highway", "")
        try:
            width = float(str(tags.get("width", "")).lower().replace("m", "").strip())
        except ValueError:
            width = float(ROAD_WIDTH.get(hw, 5))
        if len(r.get("path", [])) >= 2:
            roads.append({"osm_id": r["osm_id"], "highway": hw, "name": tags.get("name", ""), "width": width,
                          "pts": flat(r["path"])})
    for p in src.get("places", []):
        t = p.get("tags", {})
        pos = p.get("position") or (p.get("path") or [None])[0]
        if pos is None:
            continue
        places.append({"osm_id": p["osm_id"], "name": t.get("name", ""),
                       "kind": t.get("amenity") or t.get("shop") or t.get("public_transport") or "",
                       "x": round(pos[0], 2), "z": round(-pos[1], 2)})
    sx, sz = local(*SIPOREX, lat0, lon0)
    fx, fz = local(*FICGAYO, lat0, lon0)
    return {
        "schema_version": 1,
        "source": src.get("source", "OpenStreetMap"),
        "attribution": src.get("attribution", "(c) OpenStreetMap contributors"),
        "license": src.get("license", "ODbL"),
        "siporex_x": sx, "siporex_z": sz, "ficgayo_x": fx, "ficgayo_z": fz,
        "buildings": buildings, "roads": roads, "places": places,
    }


def main():
    if len(sys.argv) != 3:
        print(__doc__); sys.exit(2)
    with open(sys.argv[1], encoding="utf-8") as f:
        src = json.load(f)
    out = convert(src)
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("batiments=%d routes=%d lieux=%d -> %s" % (len(out["buildings"]), len(out["roads"]), len(out["places"]), sys.argv[2]))


if __name__ == "__main__":
    main()
