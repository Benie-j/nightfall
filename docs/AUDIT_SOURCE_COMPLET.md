# AUDIT_SOURCE_COMPLET

Archive auditée : `NIGHTFALL_SOURCE_FULL.zip` (82 fichiers, 4 647 771 octets décompressés). Lecture directe ; outil du kit `audit_archives.py` exécuté sur les archives source et migration.

## 1. Inventaire (hors `backups/`)

| Fichier | Octets |
|---|---:|
| `.github/workflows/build.yml` | 4 772 |
| `.gitignore` | 15 |
| `README.md` | 135 |
| `THIRD_PARTY_ASSETS.md` | 881 |
| `android-host/app/build.gradle.kts` | 1 638 |
| `android-host/app/src/main/AndroidManifest.xml` | 840 |
| `android-host/app/src/main/java/com/nightfall/game/MainActivity.kt` | 1 196 |
| `android-host/app/src/main/res/layout/activity_main.xml` | 242 |
| `android-host/app/src/main/res/values/styles.xml` | 268 |
| `android-host/build.gradle.kts` | 142 |
| `android-host/gradle.properties` | 100 |
| `android-host/settings.gradle.kts` | 340 |
| `apply_step1_weapon_recoil.sh` | 8 044 |
| `audio/narration/.gitkeep` | 0 |
| `ci/validate_gltf_imports.gd` | 629 |
| `data/OPENSTREETMAP_ATTRIBUTION.txt` | 230 |
| `data/missions/mission_01.json` | 948 |
| `data/story/README.md` | 317 |
| `data/story/campaign.json` | 2 709 |
| `docs/YOPOUGON_SIPOREX_FICGAYO.md` | 2 657 |
| `export_presets.cfg` | 500 |
| `fix_diag.sh` | 1 359 |
| `fix_step2.sh` | 823 |
| `fx.gd` | 9 275 |
| `gear.gd` | 4 471 |
| `hero.gd` | 5 128 |
| `hero.gd.backup-20261112-230536` | 1 378 |
| `hero.glb` | 2 152 692 |
| `hud.gd` | 14 284 |
| `human.gd` | 2 587 |
| `main.gd` | 31 568 |
| `main.tscn` | 149 |
| `perso.jpg` | 290 763 |
| `project.godot` | 674 |
| `soldier.gd` | 3 842 |
| `step2_mouvement.sh` | 30 104 |
| `story.gd` | 1 593 |
| `tools/build_yopougon_map.py` | 5 746 |
| `tools/convert_gltf_for_godot.mjs` | 1 913 |
| `tools/fetch_models.py` | 2 985 |
| `tools/fetch_textures.py` | 2 843 |
| `tools/patch_main.py` | 3 601 |
| `tools/patch_models.py` | 3 144 |
| `war.gd` | 10 624 |
| `war.gd.backup-20261112-230649` | 5 788 |
| `weapon.gd` | 6 343 |

`backups/` : 35 fichiers (copies horodatées de `hero.gd`, `main.gd`, `war.gd`, `hud.gd`, `models/hero.glb`…), historique Termux, non migrés.

## 2. Ce qui existe réellement / ce qui manque

| Élément attendu | Présent ? | Détail |
|---|---|---|
| Scénario (`data/story/campaign.json`) | OUI | titre, synopsis (10 lignes), **6 missions** avec titre + description |
| Mission 1 (`data/missions/mission_01.json`) | OUI | 5 objectifs (`reach`, `interact`, `reach`, `collect`, `escort`) + fin |
| Missions 2 à 6 (fichiers d'objectifs) | **NON** | seuls titre + description existent dans `campaign.json` |
| Texte d'introduction (`story.gd`) | OUI | 8 pages canoniques |
| Données OSM (`data/yopougon_siporex_ficgayo.json`) | **NON** | seul le script d'extraction `tools/build_yopougon_map.py` et le fichier d'attribution existent. Le script exige Internet (Overpass) |
| `data/map/` | NON | dossier inexistant |
| Modèles 3D | 1 seul : `hero.glb` (2 152 692 o) | + copie plus petite dans `backups/models/` ; `models/` est **vide** |
| Textures | NON | `tex/` est **vide** ; `THIRD_PARTY_ASSETS.md` indique qu'elles sont téléchargées en CI (cktang88/3d-fps) : non fournies |
| Audio | NON | `audio/narration/` ne contient qu'un `.gitkeep` ; les sons Godot sont synthétisés par `fx.gd` |
| `perso.jpg` | OUI (290 763 o) | provenance/droits inconnus ; non migré |
| Licences | PARTIEL | `THIRD_PARTY_ASSETS.md` (CC BY 4.0 / CC0 pour des assets **non présents**), ODbL pour OSM (données absentes), `hero.glb` : métadonnées MIT / Microsoft 2020, **à vérifier** |

## 3. Logique Godot et état de migration

| Fichier Godot | Contenu | Migré vers Unity ? |
|---|---|---|
| `story.gd`, `campaign.json`, `mission_01.json` | récit, briefings, objectifs | **OUI** : `Resources/Data/*.json` repris sans perte de champs, chargés par `MissionDatabase` |
| `hud.gd` (menu, intro, sticks, boutons) | HUD tactile, intro, menu | PARTIEL : menu, intro, HUD tactile réécrits en uGUI ; sélecteur de qualité simplifié (Auto/Basse/Haute) |
| `weapon.gd`, `gear.gd` | armes procédurales, recul, ADS, rechargement | PARTIEL : 3 armes procédurales (fusil, pistolet, pompe) ; **pas** de munitions de réserve (240 dans `war.gd`) |
| `soldier.gd`, `human.gd`, `hero.gd` | soldats, personnage de secours, squelette `Bip01` | PARTIEL : soldats procéduraux ; **`hero.glb` non importé** |
| `war.gd` | vagues, score, combo, kill-feed, régénération, bloom de visée | NON : remplacé par missions à objectifs ; score/combo/kill-feed/régénération **absents** |
| `fx.gd` | sons synthétisés, traceurs, douilles, particules | PARTIEL : équivalents dans `Fx.cs` / `ProcAudio.cs` (sons simplifiés, sans pooling) |
| `main.gd` | ville, shaders grade/grain, brouillard, particules, sauvegarde, réglages (son, vibration, fps) | PARTIEL : ville procédurale, brouillard, post-traitement URP (profil haut), sensibilité/qualité ; réglages son/vibration/fps **absents** |
| `tools/build_yopougon_map.py` | extraction OSM (Internet) | CONSERVÉ tel quel ; `tools/osm_to_unity.py` ajouté pour convertir sa sortie |
| `android-host/`, workflows Godot | hôte Kotlin Godot | SANS OBJET pour Unity ; non touchés |

## 4. Limitations déduites de l'audit

1. **Aucune carte réelle de Yopougon ne peut être construite hors ligne** : les données OSM ne sont pas dans l'archive et l'environnement n'a pas Internet. Le chargeur OSM est livré (`OsmWorld.cs`) mais jamais exécuté sur des données réelles.
2. **Aucun asset 3D final** (personnages, armes) n'existe dans la source en dehors de `hero.glb`, qui requiert `EXT_meshopt_compression`, `EXT_texture_webp`, `KHR_mesh_quantization` : non importable nativement par Unity.
3. Missions 2 à 6 : seul le titre/la description d'origine existent ; leurs objectifs sont génériques et provisoires.
4. Textures et sons Godot « téléchargés en CI » ne sont pas dans l'archive : non intégrables.
