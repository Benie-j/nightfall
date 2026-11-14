#!/usr/bin/env python3
"""Controle STATIQUE heuristique des fichiers C# (ce n'est PAS un compilateur).
Verifie : equilibre {} () [] hors chaines/commentaires, 'using Nightfall.X' vers un namespace existant,
doublons de noms de types publics, et references Editor dans le code runtime."""
import pathlib, re, sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "UnityProject/Assets")
files = sorted(root.rglob("*.cs"))
errors = []

def strip(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            while i < n and src[i] != "\n": i += 1
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2); i = n if j < 0 else j + 2
        elif src.startswith('@"', i):
            i += 2
            while i < n:
                if src[i] == '"':
                    if src.startswith('""', i): i += 2; continue
                    break
                i += 1
            i += 1; out.append('""')
        elif c == '"':
            i += 1
            while i < n and src[i] != '"':
                i += 2 if src[i] == "\\" else 1
            i += 1; out.append('""')
        elif c == "'":
            i += 1
            while i < n and src[i] != "'":
                i += 2 if src[i] == "\\" else 1
            i += 1; out.append("' '")
        else:
            out.append(c); i += 1
    return "".join(out)

namespaces, types = set(), {}
clean = {}
for f in files:
    s = strip(f.read_text(encoding="utf-8"))
    clean[f] = s
    for m in re.finditer(r"\bnamespace\s+([\w.]+)", s): namespaces.add(m.group(1))
    for m in re.finditer(r"\b(?:public|internal)\s+(?:static\s+|sealed\s+|abstract\s+)*(?:class|struct|enum|interface|delegate\s+[\w<>\[\]\.]+)\s+(\w+)", s):
        types.setdefault(m.group(1), []).append(f)

for f, s in clean.items():
    for a, b in ("{}", "()", "[]"):
        if s.count(a) != s.count(b):
            errors.append("%s : desequilibre %s%s (%d/%d)" % (f.relative_to(root), a, b, s.count(a), s.count(b)))
    for m in re.finditer(r"^\s*using\s+(Nightfall[\w.]*)\s*;", s, re.M):
        if m.group(1) not in namespaces:
            errors.append("%s : namespace inconnu %s" % (f.relative_to(root), m.group(1)))
    p = str(f).replace("\\", "/")
    if "/Scripts/" in p and re.search(r"\busing\s+UnityEditor", s):
        errors.append("%s : code runtime qui reference UnityEditor" % f.relative_to(root))
for t, fs in types.items():
    if len(fs) > 1:
        errors.append("type public duplique %s : %s" % (t, ", ".join(str(x.relative_to(root)) for x in fs)))

print("%d fichiers C# analyses" % len(files))
for e in errors: print("ERREUR:", e)
print("Aucune erreur detectee par cette heuristique (pas une compilation)." if not errors else "%d probleme(s)" % len(errors))
sys.exit(1 if errors else 0)
