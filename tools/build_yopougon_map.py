#!/usr/bin/env python3

import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

SOUTH = 5.34000
WEST = -4.08300
NORTH = 5.36000
EAST = -4.06000

LAT0 = (SOUTH + NORTH) / 2.0
LON0 = (WEST + EAST) / 2.0

OUT = "data/yopougon_siporex_ficgayo.json"

QUERY = f"""
[out:json][timeout:120];
(
  way["building"]({SOUTH},{WEST},{NORTH},{EAST});
  way["highway"]({SOUTH},{WEST},{NORTH},{EAST});
  way["amenity"]({SOUTH},{WEST},{NORTH},{EAST});
  way["shop"]({SOUTH},{WEST},{NORTH},{EAST});
  node["amenity"]({SOUTH},{WEST},{NORTH},{EAST});
  node["shop"]({SOUTH},{WEST},{NORTH},{EAST});
  node["public_transport"]({SOUTH},{WEST},{NORTH},{EAST});
);
out body;
>;
out skel qt;
"""

ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter"
]

def local_xy(lat, lon):
    x = (lon - LON0) * 111320.0 * math.cos(
        math.radians(LAT0)
    )
    z = -(lat - LAT0) * 111320.0
    return [round(x, 2), round(z, 2)]

def request_osm():
    body = urllib.parse.urlencode(
        {"data": QUERY}
    ).encode()

    last_error = None

    for endpoint in ENDPOINTS:
        for attempt in range(3):
            try:
                req = urllib.request.Request(
                    endpoint,
                    data=body,
                    headers={
                        "User-Agent": "NightfallGame/1.0 (OSM data extraction)",
                        "Content-Type":
                            "application/x-www-form-urlencoded"
                    }
                )

                with urllib.request.urlopen(
                    req, timeout=180
                ) as response:
                    return json.loads(
                        response.read().decode("utf-8")
                    )

            except Exception as exc:
                last_error = exc
                print(
                    "Overpass retry:",
                    endpoint,
                    attempt + 1,
                    exc
                )
                time.sleep(4 * (attempt + 1))

    raise RuntimeError(
        "Impossible de récupérer les données OSM : "
        + str(last_error)
    )

def main():
    print("Extraction OSM Siporex–Ficgayo...")
    osm = request_osm()

    nodes = {}
    for element in osm.get("elements", []):
        if element.get("type") == "node":
            nodes[element["id"]] = (
                element["lat"], element["lon"]
            )

    buildings = []
    roads = []
    places = []

    for element in osm.get("elements", []):
        kind = element.get("type")
        tags = element.get("tags", {})
        eid = element.get("id")

        if kind == "node":
            if tags:
                places.append({
                    "osm_id": eid,
                    "type": "node",
                    "tags": tags,
                    "position": local_xy(
                        element["lat"], element["lon"]
                    )
                })
            continue

        if kind != "way":
            continue

        coords = []
        for ref in element.get("nodes", []):
            if ref in nodes:
                lat, lon = nodes[ref]
                coords.append(local_xy(lat, lon))

        if len(coords) < 2:
            continue

        if "building" in tags:
            if len(coords) < 4 or coords[0] != coords[-1]:
                continue

            levels = None
            try:
                levels = int(tags["building:levels"])
            except (KeyError, ValueError, TypeError):
                pass

            height = None
            raw_height = tags.get("height", "")
            try:
                height = float(
                    str(raw_height).lower().replace("m", "").strip()
                )
            except (ValueError, TypeError):
                pass

            buildings.append({
                "osm_id": eid,
                "tags": tags,
                "levels": levels,
                "height_m": height,
                "height_is_estimated": height is None and levels is None,
                "footprint": coords
            })

        elif "highway" in tags:
            roads.append({
                "osm_id": eid,
                "tags": tags,
                "path": coords
            })

        elif tags:
            places.append({
                "osm_id": eid,
                "type": "way",
                "tags": tags,
                "path": coords
            })

    result = {
        "schema_version": 1,
        "source": "OpenStreetMap",
        "attribution": "© OpenStreetMap contributors",
        "license": "ODbL",
        "origin": {
            "lat": LAT0,
            "lon": LON0
        },
        "bounds": {
            "south": SOUTH,
            "west": WEST,
            "north": NORTH,
            "east": EAST
        },
        "counts": {
            "buildings": len(buildings),
            "roads": len(roads),
            "places": len(places)
        },
        "buildings": buildings,
        "roads": roads,
        "places": places
    }

    if not buildings or not roads:
        raise RuntimeError(
            "Données insuffisantes : bâtiments ou routes absents."
        )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(
            result,
            f,
            ensure_ascii=False,
            separators=(",", ":")
        )

    print("Carte extraite :", OUT)
    print("Bâtiments :", len(buildings))
    print("Routes :", len(roads))
    print("Points d'intérêt :", len(places))
    print("Taille :", os.path.getsize(OUT), "octets")

if __name__ == "__main__":
    main()
