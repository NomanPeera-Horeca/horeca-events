#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# sync-admin-to-render.sh
#
# Render's horeca-admin static site deploys from the SEPARATE
# github.com/NomanPeera-Horeca/horeca-admin repo, where the file is named
# index.html. This repo's admin.html is the source of truth; this script
# copies admin.html → ../Horeca_Admin/index.html, commits, and pushes so
# Render auto-deploys.
#
# Usage:
#   ./scripts/sync-admin-to-render.sh "commit message"
#   ./scripts/sync-admin-to-render.sh                   # prompts for message
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_FILE="$SRC_REPO/admin.html"
DST_REPO="${HORECA_ADMIN_REPO:-$(cd "$SRC_REPO/.." && pwd)/Horeca_Admin}"
DST_FILE="$DST_REPO/index.html"

if [[ ! -f "$SRC_FILE" ]]; then
  echo "error: $SRC_FILE not found" >&2
  exit 1
fi
if [[ ! -d "$DST_REPO/.git" ]]; then
  echo "error: $DST_REPO is not a git repo." >&2
  echo "       Expected sibling clone of NomanPeera-Horeca/horeca-admin." >&2
  echo "       Clone it with:" >&2
  echo "         git clone https://github.com/NomanPeera-Horeca/horeca-admin.git \"$DST_REPO\"" >&2
  exit 1
fi

MSG="${1:-}"
if [[ -z "$MSG" ]]; then
  read -r -p "Commit message: " MSG
fi
if [[ -z "$MSG" ]]; then
  echo "error: commit message required" >&2
  exit 1
fi

SRC_SHA="$(cd "$SRC_REPO" && git rev-parse --short HEAD 2>/dev/null || echo 'uncommitted')"

echo "→ syncing admin.html ($(wc -c < "$SRC_FILE" | tr -d ' ') bytes)"
echo "  from: $SRC_FILE"
echo "    to: $DST_FILE"
cp "$SRC_FILE" "$DST_FILE"

cd "$DST_REPO"

if git diff --quiet index.html; then
  echo "→ no changes in horeca-admin/index.html — nothing to push."
  exit 0
fi

git add index.html
git commit -m "$MSG

Synced from horeca-events@${SRC_SHA} via scripts/sync-admin-to-render.sh"
git push origin main

echo ""
echo "✓ pushed. Render should auto-deploy within ~60s. Verify:"
echo "  curl -sS \"https://horeca-admin.onrender.com/?cb=\$(date +%s)\" | wc -c"
echo "  (expect the new byte count to match admin.html in horeca-events)"
