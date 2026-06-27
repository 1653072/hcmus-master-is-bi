#!/usr/bin/env bash
# Copy project Cursor skills to ~/.cursor/skills/ for personal-level reuse.
# Run from repository root after git pull to refresh local personal copies.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${REPO_ROOT}/.cursor/skills"
DEST="${HOME}/.cursor/skills"

SKILLS=(design-hop-etl debug-hop-etl learn-and-upgrade-hop-etl-skills)

echo "Source:  ${SRC}"
echo "Target:  ${DEST}"
echo ""

mkdir -p "${DEST}"

for name in "${SKILLS[@]}"; do
  if [[ ! -d "${SRC}/${name}" ]]; then
    echo "SKIP: ${name} not found under ${SRC}" >&2
    continue
  fi
  rm -rf "${DEST}/${name}"
  cp -R "${SRC}/${name}" "${DEST}/${name}"
  echo "Synced: ${name} → ${DEST}/${name}"
done

echo ""
echo "Done. Personal skills updated. Invoke: /design-hop-etl, /debug-hop-etl, /learn-and-upgrade-hop-etl-skills"
echo "Re-run this script after each 'git pull' that changes .cursor/skills/."
