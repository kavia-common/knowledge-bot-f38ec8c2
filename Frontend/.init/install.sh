#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
[ -f package.json ] || (echo 'package.json missing; scaffold failed or not run' >&2; exit 2)
MARKER="$WS/.package_json_modified"
# Decide if install is required: node_modules missing OR marker present OR package.json newer than node_modules
need_install=0
if [ ! -d node_modules ]; then need_install=1; fi
if [ -f "$MARKER" ]; then need_install=1; fi
if [ -d node_modules ] && [ "package.json" -nt "node_modules" ]; then need_install=1; fi
# Ensure minimal devDependencies exist in package.json (do not pin to risky versions)
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.devDependencies=p.devDependencies||{};let changed=false; if(!p.devDependencies.eslint){p.devDependencies.eslint='^'+(process.env.ESLINT_VERSION||'8');changed=true} if(!p.devDependencies.jest){p.devDependencies.jest='^'+(process.env.JEST_VERSION||'29');changed=true} if(changed){fs.writeFileSync('package.json',JSON.stringify(p,null,2)); fs.writeFileSync('.package_json_modified','1'); process.exit(0);} process.exit(0);" || true
# Re-evaluate marker after potential modification
[ -f "$MARKER" ] && need_install=1
if [ "$need_install" -eq 1 ]; then
  LOG="/tmp/frontend_npm_install.log"
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund --prefer-offline >"$LOG" 2>&1 || (sed -n '1,200p' "$LOG" >&2; echo 'npm ci failed' >&2; exit 4);
  else
    npm install --no-audit --no-fund --prefer-offline >"$LOG" 2>&1 || (sed -n '1,200p' "$LOG" >&2; echo 'npm install failed' >&2; exit 5);
  fi
fi
# Ensure react-test-renderer installed in devDependencies
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json')); if(p.devDependencies&&p.devDependencies['react-test-renderer']) process.exit(0); process.exit(1)" || npm install --no-audit --no-fund --save-dev react-test-renderer@latest >/tmp/frontend_rtr_install.log 2>&1 || (sed -n '1,200p' /tmp/frontend_rtr_install.log >&2; echo 'react-test-renderer install failed' >&2; exit 6)
# Final verification
command -v npm >/dev/null 2>&1 || (echo 'npm not available' >&2; exit 9)
command -v node >/dev/null 2>&1 || (echo 'node not available' >&2; exit 10)
exit 0
