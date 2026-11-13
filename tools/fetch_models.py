import json, subprocess, sys, os

API = "https://api.polyhaven.com"
GROUPS = {
    "barrier": ["jersey", "concrete_barrier", "barrier"],
    "crate": ["wooden_crate", "crate", "wooden_box"],
    "barrel": ["barrel", "oil_drum", "drum"],
    "sandbag": ["sandbag", "sand_bag"],
    "tire": ["tire", "tyre"],
    "cone": ["traffic_cone", "cone"],
}
BAD = ["gate", "tape", "crowd", "fence", "sign", "pole", "ice_cream", "wine", "plant", "chair", "table"]

def curl_json(url):
    r = subprocess.run(["curl", "-sfL", "--max-time", "60", url], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except Exception:
        return None

def curl_file(url, dest):
    d = os.path.dirname(dest)
    if d:
        os.makedirs(d, exist_ok=True)
    r = subprocess.run(["curl", "-sfL", "--max-time", "240", "-o", dest, url])
    return r.returncode == 0 and os.path.exists(dest) and os.path.getsize(dest) > 50

def choose(assets, words):
    ids = sorted(assets.keys())
    for w in words:
        for i in ids:
            if w in i.lower() and not any(b in i.lower() for b in BAD):
                return i
    return None

def gltf_node(files):
    g = files.get("gltf")
    if not isinstance(g, dict):
        return None
    for res in ("1k", "2k"):
        n = g.get(res, {})
        if isinstance(n, dict) and isinstance(n.get("gltf"), dict) and n["gltf"].get("url"):
            return n["gltf"]
    return None

def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    assets = curl_json(API + "/assets?t=models")
    if not assets:
        print("!! Liste Poly Haven illisible (réseau ?). Le jeu garde ses formes générées.")
        return 0
    ok = 0
    credits = []
    for name, words in GROUPS.items():
        aid = choose(assets, words)
        if not aid:
            print("-- aucun modèle pour", name)
            continue
        files = curl_json(API + "/files/" + aid)
        node = gltf_node(files) if files else None
        if not node:
            print("-- pas de glTF pour", aid)
            continue
        base = os.path.join(outdir, name)
        good = curl_file(node["url"], os.path.join(base, "model.gltf"))
        for rel, info in (node.get("include") or {}).items():
            if good and isinstance(info, dict) and info.get("url"):
                good = curl_file(info["url"], os.path.join(base, rel)) and good
        if good:
            print("OK  ", name, "<-", aid)
            ok += 1
            credits.append(name + " : " + aid)
        else:
            print("-- échec téléchargement", aid)
            import shutil
            shutil.rmtree(base, ignore_errors=True)
    with open(os.path.join(outdir, "CREDITS.txt"), "w") as f:
        f.write("Modèles Poly Haven (licence CC0, polyhaven.com)\n" + "\n".join(credits) + "\n")
    print("Modèles téléchargés :", ok, "/", len(GROUPS))
    return ok

if __name__ == "__main__":
    main(sys.argv[1])
