#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ZIP="${1:-}"
REPO="${2:-$HOME/nightfall}"

if [[ -z "$ZIP" || ! -f "$ZIP" ]]; then
  echo "Usage: bash termux_integrate.sh /path/NIGHTFALL_UNITY_MIGRATION_FINAL.zip [repo_path]"
  exit 2
fi
if [[ ! -d "$REPO/.git" ]]; then
  echo "ERROR: $REPO is not a Git repository"
  exit 2
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
TMP="$HOME/nightfall_migration_$STAMP"
mkdir -p "$TMP"
unzip -q "$ZIP" -d "$TMP"

# Never overwrite existing original files. Only bring in migration-owned paths.
cd "$REPO"
mkdir -p UnityProject docs tools .github/workflows

if [[ -d "$TMP/UnityProject" ]]; then
  if [[ -e UnityProject ]]; then
    mv UnityProject "UnityProject.before_migration_$STAMP"
    echo "Existing UnityProject backed up as UnityProject.before_migration_$STAMP"
  fi
  cp -a "$TMP/UnityProject" ./UnityProject
fi

if [[ -d "$TMP/SourceAssets" ]]; then
  mkdir -p SourceAssets && cp -an "$TMP/SourceAssets/." SourceAssets/
fi

for f in AUDIT.md README_FINAL.md AUDIT_SOURCE_COMPLET.md MIGRATION_REPORT.md BUILD_GUIDE_TERMUX.md UNITY_LICENSE_SETUP.md KNOWN_ISSUES.md; do
  [[ -f "$TMP/$f" ]] && cp -n "$TMP/$f" docs/ || true
done

if [[ -d "$TMP/docs" ]]; then
  find "$TMP/docs" -maxdepth 1 -type f -exec cp -n {} docs/ \;
fi
if [[ -d "$TMP/tools" ]]; then
  find "$TMP/tools" -maxdepth 1 -type f -exec cp -n {} tools/ \;
fi
if [[ -d "$TMP/.github/workflows" ]]; then
  find "$TMP/.github/workflows" -maxdepth 1 -type f -exec cp -n {} .github/workflows/ \;
fi

echo
echo "Migration files copied. Original Godot files were not touched."
echo "Review changes before committing:"
git status --short
echo
echo "Temporary extraction: $TMP"
