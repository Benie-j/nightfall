#!/usr/bin/env python3
"""Audit one or more ZIP archives; Python standard library only."""
import sys, zipfile, pathlib, collections, re

KEYS = [
    "project.godot", "main.gd", "main.tscn", "story.gd", "hero.gd",
    "human.gd", "soldier.gd", "weapon.gd", "war.gd",
    "data/story", "data/missions", "data/map", "audio",
    "tools/build_yopougon_map.py", "THIRD_PARTY_ASSETS.md",
    ".github/workflows", "UnityProject/ProjectSettings/ProjectVersion.txt",
    "UnityProject/Packages/manifest.json"
]

def audit(path):
    p = pathlib.Path(path)
    print(f"\n=== {p.name} ({p.stat().st_size:,} bytes) ===")
    try:
        with zipfile.ZipFile(p) as z:
            bad = z.testzip()
            if bad:
                print("ERROR: CRC failure:", bad)
                return
            names = [n.replace("\\", "/") for n in z.namelist() if not n.endswith("/")]
            print("Files:", len(names))
            total = sum(i.file_size for i in z.infolist())
            print("Uncompressed bytes:", f"{total:,}")
            for key in KEYS:
                matches = [n for n in names if n == key or n.startswith(key.rstrip("/") + "/") or n.endswith("/" + key)]
                print(f"{'FOUND' if matches else 'MISS ':5} {key}" + (f" ({len(matches)})" if matches else ""))
            exts = collections.Counter(pathlib.PurePosixPath(n).suffix.lower() or "[no extension]" for n in names)
            print("Extensions:", ", ".join(f"{k}:{v}" for k,v in exts.most_common(25)))
            large = sorted((i.file_size, i.filename) for i in z.infolist() if not i.is_dir())[-15:][::-1]
            print("Largest files:")
            for size, name in large:
                print(f"  {size:>10,}  {name}")
            secrets = [n for n in names if re.search(r'(^|/)(Unity_lic\.ulf|.*\.keystore|.*\.jks|\.env)$', n, re.I)]
            if secrets:
                print("WARNING: possible sensitive files:", *secrets, sep="\n  ")
    except (zipfile.BadZipFile, OSError) as e:
        print("ERROR:", e)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: audit_archives.py archive1.zip [archive2.zip ...]")
        sys.exit(2)
    for arg in sys.argv[1:]:
        audit(arg)
