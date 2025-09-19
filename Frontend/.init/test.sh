#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
mkdir -p src/__tests__
TEST_FILE="src/__tests__/smoke.test.js"
if [ ! -f "$TEST_FILE" ]; then
  cat > "$TEST_FILE" <<'EOF'
const React = require('react');
const renderer = require('react-test-renderer');
function TestComponent(){return React.createElement('div',null,'ok')}
test('smoke renders', ()=>{ const tree = renderer.create(React.createElement(TestComponent)).toJSON(); expect(tree).toBeTruthy(); });
EOF
fi
# Ensure node_modules present; only install when missing to avoid network unless required
if [ ! -d node_modules ]; then
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund --prefer-offline || { echo 'npm ci failed' >&2; exit 2; }
  else
    npm install --no-audit --no-fund --prefer-offline || { echo 'npm install failed' >&2; exit 3; }
  fi
fi
# Ensure react-test-renderer exists locally
if [ ! -f node_modules/react-test-renderer/package.json ]; then
  npm install --no-audit --no-fund --save-dev react-test-renderer@latest || { echo 'install react-test-renderer failed' >&2; exit 4; }
fi
# Run tests with project-local jest
if [ -x "./node_modules/.bin/jest" ]; then
  ./node_modules/.bin/jest --runInBand || { echo 'tests failed' >&2; exit 5; }
else
  echo 'local jest not found; ensure deps step succeeded' >&2; exit 6
fi
exit 0
