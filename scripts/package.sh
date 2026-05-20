#!/usr/bin/env bash
# Build a .skill file from skills/vgpt for distribution to Claude for Excel / claude.ai users.
#
# A .skill file is just a renamed .zip containing a folder with a valid SKILL.md inside.
# Run this from the repo root: ./scripts/package.sh
#
# Output: dist/vgpt-skill.skill

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_SRC="$REPO_ROOT/skills/vgpt"
DIST="$REPO_ROOT/dist"
OUTPUT="$DIST/vgpt-skill.skill"

if [[ ! -f "$SKILL_SRC/SKILL.md" ]]; then
  echo "Error: $SKILL_SRC/SKILL.md not found" >&2
  exit 1
fi

mkdir -p "$DIST"
rm -f "$OUTPUT"

# Stage to a temp dir with the skill folder name, then zip.
# The .skill file must contain ONE top-level folder with SKILL.md inside.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -r "$SKILL_SRC" "$STAGING/vgpt-skill"

# Use the system zip; -r recursive, -q quiet.
(cd "$STAGING" && zip -qr "$OUTPUT" "vgpt-skill")

echo "✅ Built: $OUTPUT"
echo "   Size: $(du -h "$OUTPUT" | cut -f1)"
echo ""
echo "Test by uploading to Claude → Settings → Capabilities → Skills"
