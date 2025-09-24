#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# if package.json exists, assume project present
if [ -f package.json ]; then echo "SKIP: package.json exists"; exit 0; fi
# if dir not empty (other than dotfiles) skip to avoid overwriting
if [ -n "$(find . -maxdepth 1 -type f ! -name '.*' -printf '.' -quit)" ] || [ -n "$(find . -maxdepth 1 -type d ! -name '.' ! -name 'node_modules' -printf '.' -quit)" ]; then
  echo "SKIP: workspace not empty and no package.json present"; exit 0
fi
# determine template
TEMPLATE=""
if [ -f tsconfig.json ] || [ "${REQUEST_TS:-0}" = "1" ]; then TEMPLATE="--template typescript"; fi
# prefer installed create-react-app, else npx fallback
if command -v create-react-app >/dev/null 2>&1; then
  create-react-app . --use-npm $TEMPLATE --silent
else
  npx --yes create-react-app . --use-npm $TEMPLATE --silent
fi
# ensure package.json created
if [ ! -f package.json ]; then echo "ERROR: CRA did not create package.json" >&2; exit 2; fi
