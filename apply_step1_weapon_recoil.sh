#!/data/data/com.termux/files/usr/bin/bash
# Nightfall — Étape 1 : arme détaillée + recoil + posture aim + spacing ennemis
# Usage : cd \~/nightfall && bash apply_step1_weapon_recoil.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "./hero.gd" && -f "./war.gd" ]]; then
  PROJECT_DIR="$(pwd)"
elif [[ -f "$SCRIPT_DIR/hero.gd" ]]; then
  PROJECT_DIR="$SCRIPT_DIR"
elif [[ -f "$HOME/nightfall/hero.gd" ]]; then
  PROJECT_DIR="$HOME/nightfall"
else
  echo "ERREUR : hero.gd / war.gd introuvables."
  echo "Lance ce script depuis le dossier nightfall."
  exit 1
fi

cd "$PROJECT_DIR"
echo "==> Projet : $PROJECT_DIR"

for f in hero.gd war.gd; do
  if [[ ! -f "$f" ]]; then
    echo "ERREUR : fichier manquant : $f"
    exit 1
  fi
done

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="backups/auto-$STAMP"
mkdir -p "$BACKUP_DIR"
cp -f hero.gd war.gd "$BACKUP_DIR/"
echo "==> Backup : $BACKUP_DIR/"

if grep -q "NIGHTFALL_STEP1_WEAPON_RECOIL" hero.gd 2>/dev/null; then
  echo "INFO : correctifs étape 1 déjà présents — abandon."
  exit 0
fi

python3 - <<'PY'
import re, pathlib

root = pathlib.Path(".").resolve()
hero_path = root / "hero.gd"
war_path  = root / "war.gd"
hero = hero_path.read_text(encoding="utf-8")
war  = war_path.read_text(encoding="utf-8")

# ========== HERO.GD ==========
if "NIGHTFALL_STEP1_WEAPON_RECOIL" not in hero:
    if "var recoil :=" not in hero and "var recoil:=" not in hero:
        hero = hero.replace(
            "var aim_weight := 0.0\n",
            "var aim_weight := 0.0\n\nvar recoil := 0.0\nvar weapon_attach: Node3D = null\n"
        )

    anchor = '\tprint("NIGHTFALL : ", bone_ids.size(), "/", BONE_NAMES.size(), " os reconnus.")\n'
    attach_block = (
        '\tprint("NIGHTFALL : ", bone_ids.size(), "/", BONE_NAMES.size(), " os reconnus.")\n'
        '\n'
        '\t# NIGHTFALL_STEP1_WEAPON_RECOIL — point d\'attache arme\n'
        '\tweapon_attach = Node3D.new()\n'
        '\tweapon_attach.name = "WeaponAttach"\n'
        '\tadd_child(weapon_attach)\n'
        '\tweapon_attach.position = Vector3(0.28, 1.35, -0.25)\n'
    )
    if anchor in hero and "WeaponAttach" not in hero:
        hero = hero.replace(anchor, attach_block)

    old_arms = '''\t# Bras : balancement ou posture de visée
\t_pose(
\t\t"Bip01 L UpperArm",
\t\tVector3.RIGHT,
\t\tlerpf(-stride * 0.45, -0.85, aim_weight)
\t)

\t_pose(
\t\t"Bip01 R UpperArm",
\t\tVector3.RIGHT,
\t\tlerpf(-opposite * 0.45, -0.95, aim_weight)
\t)

\t_pose(
\t\t"Bip01 L Forearm",
\t\tVector3.RIGHT,
\t\tlerpf(0.0, -0.45, aim_weight)
\t)

\t_pose(
\t\t"Bip01 R Forearm",
\t\tVector3.RIGHT,
\t\tlerpf(0.0, -0.35, aim_weight)
\t)

\t# Torse
\t_pose(
\t\t"Bip01 Spine2",
\t\tVector3.RIGHT,
\t\tbreathing - 0.06 * aim_weight
\t)
'''

    new_arms = '''\t# Bras : balancement ou posture de visée + recoil
\t# NIGHTFALL_STEP1_WEAPON_RECOIL
\tvar recoil_arm := recoil * 0.35
\t_pose(
\t\t"Bip01 L UpperArm",
\t\tVector3.RIGHT,
\t\tlerpf(-stride * 0.45, -0.85 - recoil_arm * 0.3, aim_weight)
\t)

\t_pose(
\t\t"Bip01 R UpperArm",
\t\tVector3.RIGHT,
\t\tlerpf(-opposite * 0.45, -0.95 - recoil_arm, aim_weight)
\t)

\t_pose(
\t\t"Bip01 L Forearm",
\t\tVector3.RIGHT,
\t\tlerpf(0.0, -0.45, aim_weight)
\t)

\t_pose(
\t\t"Bip01 R Forearm",
\t\tVector3.RIGHT,
\t\tlerpf(0.0, -0.35 - recoil * 0.25, aim_weight)
\t)

\t# Torse + léger recul corps
\t_pose(
\t\t"Bip01 Spine2",
\t\tVector3.RIGHT,
\t\tbreathing - 0.06 * aim_weight - recoil * 0.12
\t)
\t_pose(
\t\t"Bip01 Spine1",
\t\tVector3.RIGHT,
\t\t-recoil * 0.08
\t)

\t# Décroissance du recoil
\trecoil = maxf(0.0, recoil - delta * 8.0)
'''

    if old_arms in hero:
        hero = hero.replace(old_arms, new_arms)
    else:
        pattern = re.compile(
            r'\t# Bras : balancement ou posture de visée\n.*?_pose\(\s*"Bip01 Spine2".*?\n\t\)\n',
            re.DOTALL
        )
        if pattern.search(hero):
            hero = pattern.sub(new_arms, hero, count=1)
        else:
            print("ATTENTION : bloc bras/torse non trouvé exactement dans hero.gd")

    if "func apply_recoil" not in hero:
        hero = hero.rstrip() + "\n\nfunc apply_recoil(amount: float = 0.45) -> void:\n\trecoil = minf(1.2, recoil + amount)\n"

    hero_path.write_text(hero, encoding="utf-8")
    print("OK hero.gd")
else:
    print("hero.gd déjà patché")

# ========== WAR.GD ==========
if "NIGHTFALL_STEP1_WEAPON_RECOIL" not in war:
    old_weapon = '''\t_box(Vector3(0.08, 0.12, 0.7), Vector3(0.3, 1.25, -0.45), _mat(Color(0.05, 0.05, 0.05)), player)
\tflash = OmniLight3D.new()
\tflash.position = Vector3(0.3, 1.25, -0.9)
\tflash.light_energy = 0.0
\tflash.omni_range = 8.0
\tflash.light_color = Color(1, 0.7, 0.3)
\tplayer.add_child(flash)
'''

    new_weapon = '''\t# NIGHTFALL_STEP1_WEAPON_RECOIL — arme détaillée (composants)
\tvar weapon_root := Node3D.new()
\tweapon_root.name = "Weapon"
\t_box(Vector3(0.04, 0.04, 0.55), Vector3(0, 0.02, -0.28), _mat(Color(0.12, 0.12, 0.13)), weapon_root)
\t_box(Vector3(0.07, 0.09, 0.28), Vector3(0, 0.0, 0.05), _mat(Color(0.18, 0.18, 0.19)), weapon_root)
\t_box(Vector3(0.05, 0.08, 0.22), Vector3(0, -0.02, 0.28), _mat(Color(0.25, 0.18, 0.12)), weapon_root)
\t_box(Vector3(0.04, 0.12, 0.05), Vector3(0, -0.09, 0.02), _mat(Color(0.15, 0.15, 0.15)), weapon_root)
\t_box(Vector3(0.035, 0.14, 0.06), Vector3(0, -0.12, 0.08), _mat(Color(0.1, 0.1, 0.11)), weapon_root)
\t_box(Vector3(0.015, 0.04, 0.015), Vector3(0, 0.06, -0.45), _mat(Color(0.08, 0.08, 0.08)), weapon_root)
\t_box(Vector3(0.02, 0.03, 0.02), Vector3(0, 0.055, 0.12), _mat(Color(0.08, 0.08, 0.08)), weapon_root)
\tweapon_root.position = Vector3(0.28, 1.32, -0.22)
\tweapon_root.rotation_degrees = Vector3(5, 0, 8)
\tplayer.add_child(weapon_root)
\tflash = OmniLight3D.new()
\tflash.position = Vector3(0, 0.02, -0.58)
\tflash.light_energy = 0.0
\tflash.omni_range = 6.0
\tflash.light_color = Color(1.0, 0.75, 0.35)
\tweapon_root.add_child(flash)
'''

    if old_weapon in war:
        war = war.replace(old_weapon, new_weapon)
    else:
        pat = re.compile(
            r'\t_box\(Vector3\(0\.08, 0\.12, 0\.7\).*?\n'
            r'\tflash = OmniLight3D\.new\(\)\n'
            r'.*?player\.add_child\(flash\)\n',
            re.DOTALL
        )
        if pat.search(war):
            war = pat.sub(new_weapon, war, count=1)
        else:
            print("ATTENTION : bloc arme original non trouvé dans war.gd")

    if "player.apply_recoil" not in war:
        old_shoot = "\tflash.light_energy = 6.0\n"
        new_shoot = (
            "\tflash.light_energy = 6.0\n"
            "\tif player.has_method(\"apply_recoil\"):\n"
            "\t\tplayer.apply_recoil(0.5)\n"
            "\tif player.has_method(\"set_aiming\"):\n"
            "\t\tplayer.set_aiming(true)\n"
        )
        if old_shoot in war:
            war = war.replace(old_shoot, new_shoot, 1)

    old_ai = '''\t\tif dist > 14.0:
\t\t\te.position += dir * 3.2 * delta
\t\t\te.position.x = clampf(e.position.x, -10.0, 10.0)
'''
    new_ai = '''\t\t# NIGHTFALL_STEP1_WEAPON_RECOIL — spacing
\t\tif dist > 18.0:
\t\t\te.position += dir * 3.0 * delta
\t\t\te.position.x = clampf(e.position.x, -12.0, 12.0)
\t\telif dist < 10.0:
\t\t\te.position -= dir * 1.5 * delta
'''
    if old_ai in war:
        war = war.replace(old_ai, new_ai)
    else:
        pat_ai = re.compile(
            r'\tif dist > 14\.0:\n'
            r'\t\te\.position \+= dir \* 3\.2 \* delta\n'
            r'\t\te\.position\.x = clampf\(e\.position\.x, -10\.0, 10\.0\)\n'
        )
        if pat_ai.search(war):
            war = pat_ai.sub(new_ai, war, count=1)

    war_path.write_text(war, encoding="utf-8")
    print("OK war.gd")
else:
    print("war.gd déjà patché")

print("==> Modifications écrites.")
PY

echo ""
echo "==> Vérification :"
grep -n "NIGHTFALL_STEP1_WEAPON_RECOIL\|apply_recoil\|WeaponAttach\|weapon_root\|dist > 18" hero.gd war.gd || true
echo ""
echo "Terminé. Rebuild APK pour tester."
echo "Rollback : cp $BACKUP_DIR/hero.gd . && cp $BACKUP_DIR/war.gd ."
