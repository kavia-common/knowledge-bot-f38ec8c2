#!/usr/bin/env bash
set -euo pipefail
WORKDIR="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WORKDIR"
# Detect CRA via package.json react-scripts
if [ -f package.json ]; then
  node -e "const fs=require('fs'); try{const p=JSON.parse(fs.readFileSync('package.json')); if((p.dependencies&&p.dependencies['react-scripts'])||(p.devDependencies&&p.devDependencies['react-scripts'])) process.exit(0);}catch(e){} process.exit(1)" >/dev/null 2>&1 && { echo 'CRA detected via package.json'; exit 0; }
fi
# also check common CRA files
if [ -f public/index.html ] || compgen -G "src/index.*" >/dev/null; then echo 'CRA-like files present'; exit 0; fi
# Abort if non-empty unless CLEAN_WORKSPACE=1
if [ "$(ls -A | wc -l)" -gt 0 ] && [ "${CLEAN_WORKSPACE:-0}" != "1" ]; then echo 'workspace non-empty and not a CRA project; aborting scaffold. To force scaffold set CLEAN_WORKSPACE=1' >&2; exit 6; fi
# Determine CRA usage: prefer global if semver >=5
USE_LOCAL_CRA=0
CRA_VER=""
if command -v create-react-app >/dev/null 2>&1; then
  CRA_VER="$(create-react-app --version 2>/dev/null || true)"
  if [ -z "$CRA_VER" ]; then CRA_VER="$(npm view create-react-app version 2>/dev/null || true)"; fi
  if [ -n "$CRA_VER" ]; then CRA_MAJOR=$(echo "$CRA_VER" | sed -E 's/^([0-9]+).*/\1/'); if [ "$CRA_MAJOR" -ge 5 ] 2>/dev/null; then USE_LOCAL_CRA=1; fi; fi
fi
# Run scaffold
if [ "$USE_LOCAL_CRA" -eq 1 ]; then
  create-react-app . --use-npm --silent >/tmp/cra_create.log 2>&1 || { tail -n 200 /tmp/cra_create.log; echo 'create-react-app failed' >&2; exit 7; }
else
  env HUSKY=0 npx --yes --timeout=120000 create-react-app@latest . --use-npm >/tmp/cra_create.log 2>&1 || { tail -n 200 /tmp/cra_create.log; echo 'npx create-react-app failed' >&2; exit 8; }
fi
# Post-create: ensure react/react-dom/react-scripts exist
node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json')); if(!(p.dependencies&&p.dependencies.react&&p.dependencies['react-dom']&&((p.dependencies['react-scripts'])||(p.devDependencies&&p.devDependencies['react-scripts'])))) process.exit(1)" >/dev/null 2>&1 || { echo 'CRA scaffold failed to produce required deps' >&2; exit 9; }
# Write minimal .env and .gitignore
cat > "$WORKDIR/.env" <<'EOF'
REACT_APP_API_BASE_URL=http://localhost:8080/api
REACT_APP_GOOGLE_GEMINI_KEY=replace_with_key
EOF
cat > "$WORKDIR/.gitignore" <<'EOF'
node_modules/
build/
.env
EOF
# Log CRA version to versions file if present
if [ -n "${CRA_VER:-}" ]; then
  mkdir -p /tmp
  if [ -f /tmp/frontend_env_versions.txt ]; then
    echo "CRA_USED=$CRA_VER" >> /tmp/frontend_env_versions.txt
  else
    echo "CRA_USED=$CRA_VER" > /tmp/frontend_env_versions.txt
    chmod 644 /tmp/frontend_env_versions.txt
  fi
fi

echo 'scaffold complete'
