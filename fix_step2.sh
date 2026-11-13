#!/data/data/com.termux/files/usr/bin/bash
# Nightfall - Correctif etape 2 : 3 lignes GDScript a typer explicitement
# (var x := ... sur une valeur non typee = erreur de script = ecran gris).
# Usage : cd ~/nightfall && bash fix_step2.sh
set -euo pipefail
if [[ ! -f main.gd || ! -f war.gd ]]; then
  echo "ERREUR : lance depuis le dossier nightfall."
  exit 1
fi
STAMP="$(date +%Y%m%d-%H%M%S)"
B="backups/fix2-$STAMP"
mkdir -p "$B"
cp -f main.gd war.gd "$B/"
sed -i 's|^\tvar sens := LOOK_SENS|\tvar sens: float = LOOK_SENS|' main.gd
sed -i 's|^\tvar want_sprint := |\tvar want_sprint: bool = |' main.gd
sed -i 's|^\tvar gap := 6.0|\tvar gap: float = 6.0|' war.gd
echo "==> Verification (3 lignes attendues) :"
grep -n "var sens: float\|var want_sprint: bool\|var gap: float" main.gd war.gd
echo "Rollback : cp $B/*.gd ."
