import json, subprocess, sys, os

API = "https://api.polyhaven.com"
GROUPS = {
    "conc": ["concrete_wall", "concrete_slab", "concrete_floor", "concrete"],
    "road": ["asphalt", "road"],
    "rust": ["rusty_metal", "rust", "corrugated_iron"],
    "wood": ["wood_plank", "plank", "wood"],
    "sand": ["sand", "dirt", "gravel"],
}
BAD = ["tile", "wet", "snow", "mud", "moss", "grass", "leaf", "marble", "carpet", "fabric"]

def curl_json(url):
    r = subprocess.run(["curl", "-sfL", "--max-time", "60", url], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except Exception:
        return None

def curl_file(url, dest):
    r = subprocess.run(["curl", "-sfL", "--max-time", "180", "-o", dest, url])
    return r.returncode == 0 and os.path.getsize(dest) > 1000

def pick_url(files, wanted):
    for key, val in files.items():
        k = key.lower()
        if any(w == k for w in wanted):
            for res in ("1k", "2k"):
                node = val.get(res, {}) if isinstance(val, dict) else {}
                jpg = node.get("jpg")
                if jpg and jpg.get("url"):
                    return jpg["url"]
    return None

def choose(assets, words):
    ids = sorted(assets.keys())
    for w in words:
        for i in ids:
            if w in i.lower() and not any(b in i.lower() for b in BAD):
                return i
    return None

def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    assets = curl_json(API + "/assets?t=textures")
    if not assets:
        print("!! Impossible de lire la liste Poly Haven (réseau ?). Le jeu garde ses textures générées.")
        return 0
    ok = 0
    credits = []
    for name, words in GROUPS.items():
        aid = choose(assets, words)
        if not aid:
            print("-- aucun asset pour", name)
            continue
        files = curl_json(API + "/files/" + aid)
        if not files:
            print("-- fichiers introuvables pour", aid)
            continue
        d = pick_url(files, ["diffuse", "diff", "color"])
        n = pick_url(files, ["nor_gl", "normal"])
        if not d:
            print("-- pas de diffuse pour", aid)
            continue
        if curl_file(d, os.path.join(outdir, name + "_diff.jpg")):
            print("OK  ", name, "<-", aid)
            ok += 1
            credits.append(name + " : " + aid)
            if n:
                curl_file(n, os.path.join(outdir, name + "_nor.jpg"))
        else:
            print("-- échec téléchargement", aid)
    with open(os.path.join(outdir, "CREDITS.txt"), "w") as f:
        f.write("Textures Poly Haven (licence CC0, polyhaven.com)\n" + "\n".join(credits) + "\n")
    print("Textures téléchargées :", ok, "/", len(GROUPS))
    return ok

if __name__ == "__main__":
    main(sys.argv[1])
