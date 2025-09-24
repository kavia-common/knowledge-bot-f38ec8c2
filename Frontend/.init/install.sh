#!/usr/bin/env bash
set -euo pipefail
# Install project-local npm deps non-interactively, ensure test/lint tools and configs
WORKDIR="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WORKDIR"
[ -f package.json ] || { echo 'package.json missing, run scaffold first' >&2; exit 10; }
LOG=/tmp/npm-install.log; : > "$LOG"; chmod 0644 "$LOG"
# Install using npm ci when lockfile present
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund >"$LOG" 2>&1 || { tail -n 200 "$LOG"; echo 'npm ci failed' >&2; exit 11; }
else
  npm i --no-audit --no-fund >"$LOG" 2>&1 || { tail -n 200 "$LOG"; echo 'npm install failed' >&2; exit 12; }
fi
# Ensure required devDependencies: jest, jsdom, cross-env
node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json')); const dev=p.devDependencies||{}; if(dev.jest&&dev.jsdom&&dev['cross-env']) process.exit(0); process.exit(1);" >/dev/null 2>&1 || {
  npm i -D --no-audit --no-fund jest jsdom cross-env >>"$LOG" 2>&1 || { tail -n 200 "$LOG"; echo 'installing test deps failed' >&2; exit 13; }
}
# Add minimal ESLint + Prettier config if absent
if [ ! -f .eslintrc.json ]; then cat > .eslintrc.json <<'EOF'
{"env":{"browser":true,"es2021":true},"extends":["eslint:recommended"],"rules":{}}
EOF
fi
if [ ! -f .prettierrc ]; then cat > .prettierrc <<'EOF'
{"singleQuote":true,"trailingComma":"es5"}
EOF
fi
# Verify critical packages exist in package.json
node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json')); const has=(k)=>!!((p.dependencies&&p.dependencies[k])||(p.devDependencies&&p.devDependencies[k])); if(!(has('react')&&has('react-dom')&&(has('react-scripts')))) { console.error('missing'); process.exit(1); }" >/dev/null 2>&1 || { echo 'react/react-dom/react-scripts missing after install' >&2; tail -n 200 "$LOG" || true; exit 14; }
# Success
echo 'install: completed successfully' >&2
