# BUILD_GUIDE_TERMUX — intégration et compilation (téléphone uniquement)

Rien n'est compilé sur le téléphone : Termux prépare/pousse le dépôt, **GitHub Actions** compile.

## 1. Intégrer sans rien écraser
```bash
pkg install -y unzip python git            # une fois
termux-setup-storage                       # une fois
cd ~/nightfall
git status --short                         # état propre souhaité
git checkout -b feat/unity-migration       # ne PAS toucher à main sans autorisation
unzip -q -o ~/storage/downloads/NIGHTFALL_UNITY_MIGRATION_FINAL.zip tools/termux_integrate.sh -d ~/nf_tmp
bash ~/nf_tmp/tools/termux_integrate.sh ~/storage/downloads/NIGHTFALL_UNITY_MIGRATION_FINAL.zip ~/nightfall
```
Le script sauvegarde un éventuel `UnityProject/` existant en `UnityProject.before_migration_<date>`, copie les docs/outils/workflows avec `cp -n` et laisse les fichiers Godot intacts.

## 2. Contrôles locaux (statiques, pas une compilation)
```bash
python3 tools/check_csharp_static.py UnityProject/Assets
python3 tools/verify_unity_project.py UnityProject
python3 tools/tests/test_osm_to_unity.py
python3 tools/tests/test_triangulation_port.py
```

## 3. Données OSM (optionnel, pour la vraie carte)
```bash
python3 tools/build_yopougon_map.py       # nécessite Internet (Overpass) -> data/yopougon_siporex_ficgayo.json
python3 tools/osm_to_unity.py data/yopougon_siporex_ficgayo.json \
        UnityProject/Assets/Nightfall/Resources/Data/yopougon_unity.json
```
Si `yopougon_unity.json` est présent, la mission 1 construit la carte OSM ; sinon elle utilise le décor procédural. Conserver l'attribution © OpenStreetMap contributors (ODbL).

## 4. Pousser
```bash
git add UnityProject tools .github/workflows/unity-*.yml *.md
git status
git commit -m "Migration Unity 6 + URP (2e livraison)"
git push -u origin feat/unity-migration
```

## 5. Compiler via GitHub Actions
1. Configurer la licence : `UNITY_LICENSE_SETUP.md` (obligatoire).
2. Actions → **Unity - verification et tests** → Run workflow (branche `feat/unity-migration`). Renvoyer le log si erreurs de compilation.
3. Actions → **Unity - APK Android (ARM32 + ARM64)** → Run workflow.
4. Artefacts : `nightfall-arm32-apk` (`nightfall-arm32.apk`, `lib/armeabi-v7a` seul) et `nightfall-arm64-apk` (`nightfall-arm64.apk`, `lib/arm64-v8a` seul). Le workflow vérifie l'ABI avec `verify_apk_arch.py` et compare versionName/versionCode.
5. Choisir l'APK : `getprop ro.product.cpu.abi` dans Termux (`arm64-v8a` → ARM64, `armeabi-v7a` → ARM32).

## 6. hero.glb (optionnel, non testé)
`bash tools/convert_hero_glb.sh` (Node requis ; `sharp` peut échouer sous Termux → l'exécuter dans GitHub Actions). L'import dans Unity exigerait glTFast, non ajouté.
