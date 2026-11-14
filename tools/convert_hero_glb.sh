#!/data/data/com.termux/files/usr/bin/bash
# NON TESTÉ. Tente de rendre hero.glb importable (supprime meshopt/quantization, convertit WebP en PNG).
# Usage : bash tools/convert_hero_glb.sh   (nécessite Node ; peut échouer sous Termux à cause de 'sharp' -> lancer dans GitHub Actions)
set -euo pipefail
IN=hero.glb
OUT=UnityProject/Assets/Nightfall/Art/Characters/hero_converted.glb
mkdir -p "$(dirname "$OUT")"
npx --yes @gltf-transform/cli copy "$IN" /tmp/hero_decoded.glb
npx --yes @gltf-transform/cli dequantize /tmp/hero_decoded.glb /tmp/hero_dq.glb
npx --yes @gltf-transform/cli png /tmp/hero_dq.glb "$OUT"
echo "Écrit : $OUT (à importer avec glTFast ; non ajouté au manifest)"
