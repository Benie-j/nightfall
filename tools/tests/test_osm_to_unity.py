#!/usr/bin/env python3
"""Tests de regression du convertisseur OSM vers Unity."""
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "osm_to_unity.py"
SPEC = importlib.util.spec_from_file_location("osm_to_unity", MODULE_PATH)
osm = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(osm)


class OsmToUnityTests(unittest.TestCase):
    def setUp(self):
        self.source = {
            "schema_version": 1,
            "origin": {"lat": 5.35, "lon": -4.07},
            "buildings": [
                {
                    "osm_id": 101,
                    "footprint": [
                        [0, 0], [10, 0], [10, -8],
                        [0, -8], [0, 0]
                    ],
                    "levels": 2,
                    "height_m": 6.5,
                    "height_is_estimated": True,
                    "tags": {
                        "building": "residential",
                        "name": "Maison test"
                    }
                },
                {
                    "osm_id": 102,
                    "footprint": [[0, 0], [1, 1], [0, 0]],
                    "tags": {"building": "yes"}
                }
            ],
            "roads": [
                {
                    "osm_id": 201,
                    "path": [[0, 0], [5, -5]],
                    "tags": {
                        "highway": "residential",
                        "width": "7 m"
                    }
                },
                {
                    "osm_id": 202,
                    "path": [[0, 0]],
                    "tags": {"highway": "path"}
                }
            ],
            "places": [
                {
                    "osm_id": 301,
                    "position": [12.345, -6.789],
                    "tags": {"name": "Ecole test", "amenity": "school"}
                },
                {
                    "osm_id": 302,
                    "path": [[1.0, -2.0]],
                    "tags": {"shop": "supermarket"}
                },
                {
                    "osm_id": 303,
                    "tags": {"name": "Sans position"}
                }
            ]
        }

    def test_rejects_unknown_schema(self):
        with self.assertRaises(SystemExit):
            osm.convert({
                "schema_version": 2,
                "origin": {"lat": 0, "lon": 0}
            })

    def test_buildings(self):
        result = osm.convert(self.source)
        self.assertEqual(len(result["buildings"]), 1)
        b = result["buildings"][0]
        self.assertEqual(b["osm_id"], 101)
        self.assertEqual(b["kind"], "residential")
        self.assertEqual(b["name"], "Maison test")
        self.assertEqual(b["levels"], 2)
        self.assertTrue(b["height_estimated"])
        self.assertEqual(
            b["pts"],
            [0.0, 0.0, 10.0, 0.0, 10.0, 8.0, 0.0, 8.0]
        )

    def test_roads(self):
        result = osm.convert(self.source)
        self.assertEqual(len(result["roads"]), 1)
        road = result["roads"][0]
        self.assertEqual(road["width"], 7.0)
        self.assertEqual(road["pts"], [0.0, 0.0, 5.0, 5.0])

    def test_places(self):
        result = osm.convert(self.source)
        self.assertEqual(len(result["places"]), 2)
        self.assertEqual(result["places"][0]["kind"], "school")
        self.assertEqual(result["places"][0]["x"], 12.35)
        self.assertEqual(result["places"][0]["z"], 6.79)
        self.assertEqual(result["places"][1]["kind"], "supermarket")
        self.assertEqual(result["places"][1]["z"], 2.0)

    def test_metadata(self):
        result = osm.convert(self.source)
        self.assertEqual(result["schema_version"], 1)
        self.assertIn("OpenStreetMap", result["source"])
        self.assertIn("ODbL", result["license"])
        self.assertIn("siporex_x", result)
        self.assertIn("ficgayo_z", result)


if __name__ == "__main__":
    unittest.main(verbosity=2)
