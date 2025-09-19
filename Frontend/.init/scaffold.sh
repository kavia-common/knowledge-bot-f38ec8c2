#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
# If package.json exists and has react deps, assume scaffolded
if [ -f package.json ]; then
  node -e "const p=require('./package.json'); if(p.dependencies&&p.dependencies.react&&p.dependencies['react-dom']) process.exit(0); process.exit(1)" >/dev/null 2>&1 && exit 0 || true
fi
# Refuse to init CRA in a non-empty workspace (exclude .git) including dotfiles
shopt -s dotglob nullglob
entries=("$WS"/*)
non_git_count=0
for f in "${entries[@]}"; do
  [ "$(basename "$f")" = ".git" ] && continue
  non_git_count=$((non_git_count+1))
done
if [ "$non_git_count" -gt 0 ]; then
  echo 'workspace not empty; skipping CRA to avoid overwrite' >&2
  exit 4
fi
LOG="$WS/cra_init.log"
# Prefer preinstalled create-react-app: try --no-install via npx first, then direct global binary
if command -v npx >/dev/null 2>&1; then
  npx --no-install create-react-app . --use-npm >"$LOG" 2>&1 || true
fi
if [ ! -f package.json ]; then
  if command -v create-react-app >/dev/null 2>&1; then
    create-react-app . --use-npm >"$LOG" 2>&1 || (sed -n '1,200p' "$LOG" >&2; echo 'create-react-app failed' >&2; exit 2)
  else
    # fallback to npx with network
    npx --yes create-react-app@latest . --use-npm >"$LOG" 2>&1 || (sed -n '1,200p' "$LOG" >&2; echo 'create-react-app failed (npx)' >&2; exit 2)
  fi
fi
# Verify basic deps
node -e "const p=require('./package.json'); if(!(p.dependencies&&p.dependencies.react&&p.dependencies['react-dom'])){console.error('react deps missing'); process.exit(1)}" || (echo 'scaffold failed: react deps missing' >&2; exit 3)
# Add proxy if missing and mark package.json modified so deps step will install
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json')); if(!p.proxy){p.proxy='http://localhost:8000'; fs.writeFileSync('package.json',JSON.stringify(p,null,2)); fs.writeFileSync('.package_json_modified','1');}" || true
exit 0
