# KNOWN_ISSUES

## 0. Rien n'a été compilé ni exécuté dans Unity
Le C# (~40 fichiers) n'a jamais vu de compilateur. Des erreurs de compilation sont **probables** (API Unity 6 / URP 17 écrites sans vérification). Premier run CI = première compilation : le log d'erreurs de `unity-ci.yml` (job `unity-tests`) est le prochain point de départ.

## Risques par gravité
1. **Licence Unity en CI** : voir `UNITY_LICENSE_SETUP.md`. Unity Personal n'est activable officiellement que via Unity Hub ; la procédure GameCI Personal n'est pas garantie. Le workflow échoue explicitement à l'activation si aucun secret.
2. **Version `6000.0.40f1` + image GameCI** : existence de l'image et du changeset non vérifiée.
3. **Input Manager** : le jeu utilise `Input.touches`. Si Unity génère `activeInputHandler: 1`, le build s'arrête avec un message (et le workflow tente de forcer `0` si `ProjectSettings.asset` est committé). Premier run possible en deux passes.
4. **ARMv7** : prise en charge IL2CPP à confirmer sur 6000.0.40f1 ; le build échoue explicitement si l'architecture n'est pas appliquée.
5. **Carte OSM** : données absentes ; `OsmWorld` jamais exécuté. Orientation des faces testée seulement sur le papier/algorithme Python ; matériaux en double face par sécurité. Pas de lampadaires ni de textures sur les bâtiments OSM ; hauteurs estimées.
6. **Navigation** : grille 1,5 m (ARM64) / 2 m (ARM32) ; coût de l'échantillonnage au chargement non mesuré. Les obstacles dynamiques ne sont gérés que par raycasts locaux.
7. **Shaders** : matériaux créés à l'exécution ; risque de variantes éliminées (matériaux roses). Contre-mesures non testées.
8. **URP créé par code** (`UniversalRenderPipelineAsset.Create`) : propriétés non vérifiées sur 17.0.3.
9. **Performances** : aucune mesure. Beaucoup d'objets individuels, pas de pooling pour impacts/traceurs.
10. **Ordre d'exécution UI/scripts** : les appuis ponctuels sont conservés une frame de plus pour compenser ; comportement sur appareil non vérifié.
11. Les `.meta` sont générés par Unity ; à committer après le premier import réussi.

## Contenu manquant / provisoire
- Pas de carte réelle de Yopougon (données OSM absentes).
- Pas de modèles 3D finaux (personnages/armes procéduraux ; `hero.glb` non importable tel quel).
- Pas d'audio réel (sons synthétisés ; `audio/narration/` vide dans la source).
- Missions 2–6 : objectifs génériques ; positions des objectifs de la mission 1 inventées (absentes de la source).
- Absents : munitions de réserve, score/combo/kill-feed, régénération, réglages son/vibration/fps.

## Licences
- `hero.glb` : métadonnées MIT / Microsoft 2020 (déduction à vérifier ; conserver le texte de licence).
- `perso.jpg` : provenance inconnue, non utilisé.
- `THIRD_PARTY_ASSETS.md` du dépôt Godot (CC BY 4.0 / CC0) décrit des assets **non présents** dans l'archive.
- OSM : attribution « © OpenStreetMap contributors », licence ODbL (voir `Resources/Data/OPENSTREETMAP_ATTRIBUTION.txt`) ; obligations de base de données dérivée à respecter si les données sont ajoutées.
