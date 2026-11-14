# NIGHTFALL — Les ombres de Yopougon

## Décisions
- Première zone : Siporex–Ficgayo, Yopougon.
- Reproduction géographique maximale.
- Bâtiments reconstruits individuellement.
- Personnage principal : avatar du développeur.
- Moteur : Godot 4.3.
- Plateformes : Android ARM32 et ARM64.
- Branche : feat/visual-rework.
- Ne pas modifier main.

## Histoire

En 2031, une série d'incidents inexpliqués
perturbe les communications et les transports
dans plusieurs secteurs d'Abidjan.

Le protagoniste, ancien militaire ivoirien,
est rappelé pour retrouver un informateur
à Siporex.

Cet informateur détient des preuves concernant
une organisation clandestine appelée NIGHTFALL.

Une explosion fictive interrompt la circulation.
L'équipe du protagoniste est dispersée.

Le joueur doit rejoindre la gare de Siporex,
retrouver son contact, traverser l'axe vers
Ficgayo, récupérer une preuve numérique et
escorter des civils vers une zone sûre.

La mission révèle que l'organisation prépare
une opération visant plusieurs infrastructures
stratégiques d'Abidjan.

Le récit est entièrement fictif.
Les habitants et quartiers réels ne sont pas
présentés comme des groupes hostiles.

## Références géographiques

Siporex : 5.35417, -4.07457
Ficgayo : 5.34859, -4.07196

Emprise initiale :
- sud : 5.34000
- ouest : -4.08300
- nord : 5.36000
- est : -4.06000

Cette emprise sera ajustée après inspection
des données téléchargées.

## Pipeline

1. Télécharger les routes et bâtiments OSM.
2. Conserver les identifiants et tags originaux.
3. Convertir WGS84 en coordonnées locales métriques.
4. Construire les empreintes des bâtiments.
5. Construire les routes et intersections.
6. Ajouter les façades à partir de références visuelles.
7. Ajouter collisions, LOD et optimisation.
8. Vérifier les parcours dans Godot.

Les hauteurs absentes des données OSM ne seront
pas présentées comme des mesures exactes.

## Optimisation mobile

- Données intégrées hors ligne.
- Pas de requête réseau en jeu.
- Regroupement des meshes par secteur.
- LOD et collisions simplifiées.
- Mesures séparées ARM32 et ARM64.

## Avatar

Le dépôt contient déjà perso.jpg.
Il est actuellement utilisé par human.gd,
le personnage de secours.

Il reste à intégrer la référence au véritable
modèle 3D du héros et à vérifier son animation.
Une seule photo ne suffit pas à reconstruire
fidèlement un visage en trois dimensions.

## Attribution

OpenStreetMap contributors :
https://www.openstreetmap.org/copyright

Données sous licence ODbL.
Les autres modèles, photos et textures doivent
avoir une licence vérifiée.
