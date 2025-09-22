#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
# if a package.json does not exist, create a minimal CRA-compatible one
if [ ! -f package.json ]; then cat >package.json <<'JSON'
{
  "name": "kb-frontend",
  "version": "0.0.0",
  "private": true,
  "scripts": {"start":"react-scripts start","build":"react-scripts build","test":"react-scripts test"},
  "dependencies": {"react":"18.2.0","react-dom":"18.2.0","react-scripts":"5.0.1"}
}
JSON
fi
# install project dependencies non-interactively
npm i --no-audit --no-fund --silent
