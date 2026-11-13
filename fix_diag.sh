#!/data/data/com.termux/files/usr/bin/bash
# Nightfall - Diagnostic precis du chargement de hero.glb (cause exacte affichee a l'ecran)
# Usage : cd ~/nightfall && bash fix_diag.sh
set -euo pipefail
if [[ ! -f hero.gd || ! -f war.gd ]]; then
  echo "ERREUR : lance depuis le dossier nightfall."
  exit 1
fi
if grep -q "load_status" hero.gd; then
  echo "INFO : deja applique."
  exit 0
fi
STAMP="$(date +%Y%m%d-%H%M%S)"
B="backups/diag-$STAMP"
mkdir -p "$B"
cp -f hero.gd war.gd "$B/"
sed -i 's|^var skeleton: Skeleton3D$|&\nvar load_status := "inconnu"|' hero.gd
sed -i 's|^\t\tpush_error("NIGHTFALL : impossible de charger hero.glb.")|&\n\t\tload_status = "import echoue (load a renvoye null)"|' hero.gd
sed -i "s|^\t\tpush_error(\"NIGHTFALL : le modèle GLB n'est pas un Node3D.\")|&\n\t\tload_status = \"racine non Node3D\"|" hero.gd
sed -i 's|^\t\tpush_error("NIGHTFALL : dimensions du modèle invalides.")|&\n\t\tload_status = "aucun mesh / dimensions invalides"|' hero.gd
sed -i 's|^\t\tpush_error("NIGHTFALL : aucun Skeleton3D trouvé dans hero.glb.")|&\n\t\tload_status = "modele charge mais sans Skeleton3D"|' hero.gd
sed -i 's|return "Modèle : hero.glb ÉCHEC (aucun squelette)"|return "Modèle : hero.glb ÉCHEC - " + str(body_ref.load_status)|' war.gd
echo "==> Verification :"
grep -n "load_status" hero.gd war.gd
echo "Rollback : cp $B/*.gd ."
