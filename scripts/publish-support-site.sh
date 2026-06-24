#!/usr/bin/env bash
# Publishes support-site/ to AudioPig/AudioPig.github.io for GitHub Pages.
set -euo pipefail

ORG="AudioPig"
REPO="AudioPig.github.io"
PAGES_URL="https://audiopig.github.io"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/support-site"

if ! command -v gh &>/dev/null; then
  echo "ERROR: GitHub CLI (gh) is required."
  exit 1
fi

if ! gh api "/orgs/${ORG}" &>/dev/null; then
  echo "ERROR: GitHub organization '${ORG}' does not exist yet."
  echo ""
  echo "Create it (free, ~2 minutes):"
  echo "  https://github.com/account/organizations/new"
  echo "  Organization name: ${ORG}"
  echo "  Plan: Free"
  echo ""
  echo "Then re-run: ./scripts/publish-support-site.sh"
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
cp -R "$SITE"/. "$workdir/"
cd "$workdir"
git init -q
git add .
git commit -q -m "Publish Audiopig support and legal pages"

if gh repo view "${ORG}/${REPO}" &>/dev/null; then
  git branch -M main
  git remote add origin "https://github.com/${ORG}/${REPO}.git"
  git push -f origin main
else
  gh repo create "${ORG}/${REPO}" \
    --public \
    --description "Audiopig support and legal pages" \
    --source=. \
    --remote=origin \
    --push
fi

echo ""
echo "Published to https://github.com/${ORG}/${REPO}"
echo "GitHub Pages URL (may take 1–2 minutes): ${PAGES_URL}/"
echo ""
echo "If the site 404s, open repo Settings → Pages → Source: GitHub Actions."
