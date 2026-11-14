#!/usr/bin/env python3
"""Static Unity project sanity checks. This does NOT compile C# or import Unity."""
import sys, pathlib, re, json, xml.etree.ElementTree as ET

def read(p):
    try: return p.read_text(encoding="utf-8")
    except Exception: return ""

def main(root):
    root = pathlib.Path(root)
    errors, warns, oks = [], [], []
    def check(cond, msg, level="error"):
        (oks if cond else errors if level == "error" else warns).append(msg)

    pv = root/"ProjectSettings/ProjectVersion.txt"
    manifest = root/"Packages/manifest.json"
    check(pv.exists(), "ProjectVersion.txt exists")
    version = read(pv)
    check("6000.0." in version, "Unity Editor version appears to be Unity 6.0 (6000.0.x)", "warn")
    check(manifest.exists(), "Packages/manifest.json exists")
    if manifest.exists():
        try:
            packages = json.loads(read(manifest)).get("dependencies", {})
            check("com.unity.render-pipelines.universal" in packages, "URP package declared")
            print("URP:", packages.get("com.unity.render-pipelines.universal", "NOT DECLARED"))
        except Exception as e:
            errors.append(f"Invalid manifest JSON: {e}")

    scripts = list((root/"Assets").rglob("*.cs")) if (root/"Assets").exists() else []
    check(bool(scripts), f"C# scripts found ({len(scripts)})")
    for rel in [
        "Assets/Nightfall/Scripts/Core/GameBootstrap.cs",
        "Assets/Nightfall/Scripts/Core/GameFlow.cs",
        "Assets/Nightfall/Editor/BuildScript.cs",
        "Assets/Nightfall/Editor/SceneFactory.cs",
    ]:
        check((root/rel).exists(), f"Required file: {rel}")

    # Basic delimiter scan only; comments/strings can cause false positives.
    for p in scripts:
        s = read(p)
        if s.count("{") != s.count("}"):
            warns.append(f"Brace-count mismatch (heuristic): {p.relative_to(root)}")
        if "UnityEditor" in s and "/Scripts/" in str(p).replace("\\", "/"):
            warns.append(f"Runtime script references UnityEditor: {p.relative_to(root)}")

    workflows = list(root.parent.glob(".github/workflows/*.yml")) + list(root.parent.glob(".github/workflows/*.yaml"))
    check(bool(workflows), f"Workflow files found at repository parent ({len(workflows)})", "warn")
    for w in workflows:
        t = read(w)
        if "UNITY_LICENSE" in t or "UNITY_EMAIL" in t or "UNITY_SERIAL" in t:
            oks.append(f"Unity license secret references found in {w.name} (verify secrets are not hardcoded)")
        if "UNITY_PASSWORD" in t and "secrets.UNITY_PASSWORD" not in t:
            warns.append(f"Check possible hardcoded password reference in {w.name}")
        if "nightfall-arm32.apk" in t and "nightfall-arm64.apk" in t:
            oks.append(f"Both APK output names referenced in {w.name}")

    print("\nOK:")
    for x in oks: print("  +", x)
    print("\nWARNINGS:")
    for x in warns: print("  !", x)
    print("\nERRORS:")
    for x in errors: print("  x", x)
    print("\nNOTE: static inspection only; no C# compilation, Unity import, APK build, or device test.")
    return 1 if errors else 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: verify_unity_project.py /path/to/UnityProject")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
