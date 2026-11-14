#!/usr/bin/env python3
"""Inspect native ABI folders in an APK (ZIP). Does not validate runtime behavior."""
import argparse, zipfile, sys

ABI_DIRS = {
    "arm32": "lib/armeabi-v7a/",
    "arm64": "lib/arm64-v8a/",
}
REQUIRED_NATIVE = {"libil2cpp.so", "libunity.so"}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--expect", choices=["arm32", "arm64"], required=True)
    a = ap.parse_args()
    try:
        with zipfile.ZipFile(a.apk) as z:
            names = z.namelist()
            found = {abi: sorted(n for n in names if n.startswith(prefix) and n.endswith(".so"))
                     for abi, prefix in ABI_DIRS.items()}
            print("Native libraries:")
            for abi, libs in found.items():
                print(f"  {abi}: {len(libs)}")
                for lib in libs[:30]: print("   ", lib)
            expected_prefix = ABI_DIRS[a.expect]
            expected_names = {n.rsplit("/", 1)[-1] for n in found[a.expect]}
            missing = REQUIRED_NATIVE - expected_names
            unexpected_other = found["arm64" if a.expect == "arm32" else "arm32"]
            ok = bool(found[a.expect]) and not missing and not unexpected_other
            if missing: print("Missing expected core libs:", ", ".join(sorted(missing)))
            if unexpected_other: print("WARNING: other ARM ABI also present; APK is not single-ABI.")
            print("RESULT:", "PASS (ABI layout only)" if ok else "FAIL")
            return 0 if ok else 1
    except (OSError, zipfile.BadZipFile) as e:
        print("ERROR:", e)
        return 2

if __name__ == "__main__":
    sys.exit(main())
