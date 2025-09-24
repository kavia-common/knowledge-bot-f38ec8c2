#!/usr/bin/env bash
set -euo pipefail
WORKDIR="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WORKDIR"
[ -f package.json ] || { echo 'package.json missing' >&2; exit 15; }
# Ensure jest config testEnvironment=jsdom in package.json
node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json')); p.jest=p.jest||{}; if(p.jest.testEnvironment!=='jsdom'){ p.jest.testEnvironment='jsdom'; fs.writeFileSync('package.json', JSON.stringify(p,null,2)); }" >/dev/null 2>&1 || { echo 'failed to set jest testEnvironment' >&2; exit 16; }
# Detect TypeScript usage
IS_TS=0
node -e "const fs=require('fs'); try{const p=JSON.parse(fs.readFileSync('package.json')); if((p.dependencies&&p.dependencies.typescript)||(p.devDependencies&&p.devDependencies.typescript)) process.exit(0);}catch(e){} process.exit(1)" >/dev/null 2>&1 && IS_TS=1 || IS_TS=0
# Create smoke test in appropriate extension
mkdir -p src/__tests__
if [ "$IS_TS" -eq 1 ]; then
  cat > src/__tests__/smoke.test.tsx <<'EOF'
import React from 'react';
import { render } from '@testing-library/react';
function X(){return <div>ok</div>}
test('react render smoke', ()=>{ const { container } = render(<X/>); expect(container.querySelector('div')).not.toBeNull(); });
EOF
else
  # Prefer @testing-library/react if available, else react-test-renderer, else simple assertion
  node -e "try{require.resolve('@testing-library/react'); process.exit(0);}catch(e){try{require.resolve('react-test-renderer'); process.exit(2);}catch(e2){process.exit(1);}}" >/dev/null 2>&1
  R=$?
  if [ "$R" -eq 0 ]; then
    cat > src/__tests__/smoke.test.js <<'EOF'
import React from 'react';
import { render } from '@testing-library/react';
function X(){return React.createElement('div',null,'ok');}
test('react render smoke', ()=>{ const { container } = render(React.createElement(X)); expect(container.querySelector('div')).not.toBeNull(); });
EOF
  elif [ "$R" -eq 2 ]; then
    cat > src/__tests__/smoke.test.js <<'EOF'
import React from 'react';
import renderer from 'react-test-renderer';
function X(){return React.createElement('div',null,'ok');}
test('react render smoke', ()=>{ const tree=renderer.create(React.createElement(X)).toJSON(); expect(tree.type).toBe('div'); });
EOF
  else
    cat > src/__tests__/smoke.test.js <<'EOF'
test('basic smoke', ()=>{ expect(1+1).toBe(2); });
EOF
  fi
fi
# Ensure package.json has test script
node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json')); p.scripts=p.scripts||{}; if(!p.scripts.test) p.scripts.test='jest --colors --runInBand'; fs.writeFileSync('package.json', JSON.stringify(p,null,2));" >/dev/null 2>&1
# Run tests and capture npm output to /tmp/npm-test.log (0644)
npm test --silent > /tmp/npm-test.log 2>&1 || { echo 'tests failed; see /tmp/npm-test.log' >&2; tail -n +1 /tmp/npm-test.log >&2 || true; exit 17; }
# On success, print brief confirmation and show last lines of log
echo 'tests passed' > /tmp/npm-test.log.ok
tail -n 200 /tmp/npm-test.log || true
