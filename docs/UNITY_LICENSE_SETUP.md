# UNITY_LICENSE_SETUP — à faire par le propriétaire du compte Unity

La licence est un prérequis de la CI, pas une option de YAML. Aucun secret n'est dans cette archive.

## Faits (documentation Unity 6 / GameCI consultée par le kit)
- Unity Personal : activation officielle **uniquement via Unity Hub** ; l'activation en ligne de commande et manuelle `.alf/.ulf` est documentée pour Pro/Plus, pas pour Personal.
- GameCI documente une procédure Personal (secrets `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD`) et une procédure Pro (`UNITY_EMAIL`, `UNITY_PASSWORD`, `UNITY_SERIAL`). Les pages de versions ne sont pas uniformes : **non garanti sans un run réussi**.

## Étapes
1. GitHub → dépôt → Settings → Secrets and variables → Actions → New repository secret.
2. Licence **à série (Plus/Pro)** : créer `UNITY_SERIAL`, `UNITY_EMAIL`, `UNITY_PASSWORD`.
3. **Personal** : suivre https://game.ci/docs/github/activation/ pour obtenir le contenu du fichier de licence, puis créer `UNITY_LICENSE` (contenu du fichier), `UNITY_EMAIL`, `UNITY_PASSWORD`. Ne jamais committer ce fichier.
4. Lancer Actions → « Unity - verification et tests ». Si l'activation échoue, le job s'arrête à ce stade : le blocage est réel et externe au code.
5. Ne jamais mettre mot de passe, `.ulf`, série ou keystore dans le dépôt ou un ZIP.

Les APK sont signés avec la clé de debug d'Unity (aucun keystore fourni) : suffisant pour installer, pas pour publier.
