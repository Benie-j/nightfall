# MIGRATION_REPORT — NIGHTFALL Godot → Unity 6 + URP (2e livraison)

Environnement de cette livraison : **hors ligne, sans Unity Editor, sans compilateur C#, sans Android SDK, sans appareil.**
Statuts : `DONE_CODE_AND_TESTED` = code + test réellement exécuté · `IMPLEMENTED_NOT_COMPILED` = code écrit, jamais compilé · `PARTIAL` · `MISSING` · `BLOCKED_EXTERNAL`.

## Réponses directes
1. Projet complet au niveau code ? **Non** : le parcours jouable est câblé, mais carte réelle, modèles finaux et plusieurs fonctions Godot manquent (tableau).
2. Importé dans Unity ? **Non.**
3. Scripts C# compilés ? **Non.** Seul un contrôle heuristique (équilibre des accolades, `using`, doublons) a été exécuté : ce n'est pas une compilation.
4. Tests Unity réussis ? **Non, jamais exécutés.** 16 tests EditMode + 2 PlayMode sont écrits. Réellement exécutés : 2 tests Python du convertisseur OSM (fixture synthétique) et 1 test Python de l'algorithme de triangulation (port Python, 202 polygones).
5. APK ARMv7 existe ? **Non.**  6. APK ARM64 existe ? **Non.**
7. Vérifiés par ABI ? **Non** (aucun APK). `verify_apk_arch.py` est branché dans le workflow.
8. Testés sur téléphone ? **Non.**

## Corrections par rapport à la 1re livraison
| Problème | Correction | Statut |
|---|---|---|
| Tir/visée/course restaient bloqués (`FireHeld = FireHeld \|\| souris`) | entrées UI et clavier séparées, recalculées chaque frame ; reset sur pause/perte de focus/désactivation ; appuis ponctuels gardés 1 frame de plus | IMPLEMENTED_NOT_COMPILED + test EditMode écrit |
| `versionCode` 1001/1002 | même `versionName 0.2.0` et `versionCode 2` pour les deux (`BuildInfo`) | IMPLEMENTED_NOT_COMPILED |
| Chemins d'artefacts du workflow | `buildName: nightfall-<abi>`, recherche du fichier, copie dans `dist/`, `verify_apk_arch.py`, job de comparaison des versions | YAML valide (PyYAML) ; jamais exécuté |
| Briefings « [Texte provisoire] » | vrais textes de `campaign.json` | IMPLEMENTED_NOT_COMPILED |
| Navigation sans chemin (raycasts seuls) | `NavGrid` : A* sur grille échantillonnée par `Physics.CheckBox` + lissage ; utilisée par ennemis et civils | IMPLEMENTED_NOT_COMPILED + 5 tests EditMode écrits |
| Objectif unique « tuer tous » | objectifs réels de la mission 1 + victoire/échec | IMPLEMENTED_NOT_COMPILED |

## Tableau par fonctionnalité
| Fonctionnalité | État | Fichiers | Source d'origine | Test exécuté | Blocage |
|---|---|---|---|---|---|
| Récit, synopsis, 6 missions | IMPLEMENTED_NOT_COMPILED | `Resources/Data/campaign.json`, `MissionDef.cs` | `data/story/campaign.json` | JSON validé (Python) | compilation |
| Intro (8 pages) | IMPLEMENTED_NOT_COMPILED | `Data/intro.json`, `GameFlow.ShowIntro` | `story.gd` | extraction vérifiée (8 pages) | compilation |
| Objectifs mission 1 (reach/interact/reach/collect/escort) | IMPLEMENTED_NOT_COMPILED | `mission_01.json`, `MissionController.cs`, `MissionActors.cs` | `mission_01.json` | aucun | compilation ; positions des objectifs **ajoutées** (absentes de la source) |
| Missions 2–6 | PARTIAL | `MissionDatabase` | `campaign.json` (titre+description seulement) | aucun | objectifs **génériques provisoires** (atteindre / éliminer / extraction) |
| Carte réelle Siporex–Ficgayo (OSM) | **BLOCKED_EXTERNAL** | `OsmWorld.cs`, `tools/osm_to_unity.py`, `tools/build_yopougon_map.py` | `build_yopougon_map.py` | convertisseur : 2 tests Python (fixture synthétique) ; triangulation : port Python | **le fichier de données OSM n'existe pas** et Internet est requis (Overpass). Sans lui, la mission 1 utilise le décor procédural. Aucun test sur données réelles. Hauteurs estimées si absentes |
| Ville procédurale (provisoire) | IMPLEMENTED_NOT_COMPILED | `CityGenerator.cs`, `SectorStreamer.cs` | `main.gd` (concept) | aucun | décor provisoire, **pas** Yopougon |
| Joueur FPS tactile | IMPLEMENTED_NOT_COMPILED | `PlayerController.cs`, `TouchInput.cs`, `HudView.cs` | `main.gd`, `hud.gd` | test EditMode (flags) écrit | validation sur appareil |
| Armes : tir, ADS, rechargement, changement | IMPLEMENTED_NOT_COMPILED | `Weapon*.cs` | `weapon.gd`, `war.gd` | aucun | **pas de munitions de réserve** ; armes = primitives procédurales |
| Ennemis : détection, bruit, couverture, repli | IMPLEMENTED_NOT_COMPILED | `EnemyAI.cs`, `NavGrid.cs` | `soldier.gd`, `war.gd` | A* : 5 tests EditMode écrits | compilation ; comportements non joués |
| Dégâts, mort, victoire/échec | IMPLEMENTED_NOT_COMPILED | `Health.cs`, `MissionController.cs` | `war.gd` | PlayMode écrit | compilation |
| Sauvegarde (progression, meilleurs temps, intro vue, réglages) | IMPLEMENTED_NOT_COMPILED | `SaveData.cs` (PlayerPrefs) | `main.gd` (user://nightfall.cfg) | aucun | réglages son/vibration/fps absents |
| Profils ARM32 / ARM64 | IMPLEMENTED_NOT_COMPILED | `QualityProfile.cs`, `ProjectConfigurator.cs` | `export_presets.cfg` | aucun | **aucune mesure FPS/mémoire** |
| Personnages 3D / `hero.glb` | **BLOCKED_EXTERNAL** | `SourceAssets/hero.glb`, `tools/convert_hero_glb.sh` | `hero.glb`, `hero.gd` | aucun | extensions meshopt/WebP/quantization ; conversion non testée ; glTFast non ajouté (non vérifiable hors ligne) |
| Score, combo, kill-feed, régénération (`war.gd`) | MISSING | — | `war.gd` | — | non repris |
| Graphismes réalistes (textures, modèles) | PARTIAL | `Mats.cs`, `ProcTex.cs`, `NightEnvironment.cs` | — | aucun | tout est procédural/provisoire ; aucun asset réaliste dans la source |
| APK ARMv7 / ARM64 (IL2CPP, 1 ABI chacun) | IMPLEMENTED_NOT_COMPILED | `BuildScript.cs`, `unity-android.yml` | `export_presets.cfg` | YAML validé | licence Unity ; Unity 6000.0.40f1 et image GameCI non vérifiées |
| Tests Unity | IMPLEMENTED_NOT_COMPILED | `Tests/EditMode`, `Tests/PlayMode` | — | non exécutés | licence/CI |

## Décisions
- Versions inchangées : Unity `6000.0.40f1`, URP `17.0.3` (cohérentes avec le kit) ; non vérifiées contre une installation réelle.
- Aucun package ajouté : `AI Navigation` (NavMesh) et `glTFast` ne sont pas récupérables hors ligne ; navigation remplacée par `NavGrid`.
- `hero.glb` conservé hors de `Assets/` (`SourceAssets/`) pour ne pas casser l'import Unity.
- Le dépôt Godot n'est pas dupliqué ; `tools/termux_integrate.sh` copie les fichiers sans écraser (le `UnityProject` existant est sauvegardé).
