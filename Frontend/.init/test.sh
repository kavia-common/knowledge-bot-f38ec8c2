#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WORKSPACE"
# ensure jq available for JSON checks
if ! command -v jq >/dev/null 2>&1; then echo "ERROR: jq is required but not found" >&2; exit 10; fi
if [ ! -f package.json ]; then echo "ERROR: package.json missing" >&2; exit 2; fi
IS_TS=0
if [ -f tsconfig.json ]; then IS_TS=1; fi
if [ "$IS_TS" -eq 1 ]; then
  COMP=src/__TestHello__.tsx
  TEST=src/__TestHello__.test.tsx
else
  COMP=src/__TestHello__.jsx
  TEST=src/__TestHello__.test.jsx
fi
mkdir -p src
# create deterministic component if missing
if [ ! -f "$COMP" ]; then
  if [ "$IS_TS" -eq 1 ]; then
    cat > "$COMP" <<'EOF'
import React from 'react';
export default function TestHello(): JSX.Element { return <div data-testid="hello">Hello-Dev</div>; }
EOF
  else
    cat > "$COMP" <<'EOF'
import React from 'react';
export default function TestHello(){ return <div data-testid="hello">Hello-Dev</div>; }
EOF
  fi
fi
# create deterministic test if missing
if [ ! -f "$TEST" ]; then
  if [ "$IS_TS" -eq 1 ]; then
    cat > "$TEST" <<'EOF'
import React from 'react';
import { render, screen } from '@testing-library/react';
import TestHello from './__TestHello__';
test('renders Hello-Dev', () => { render(<TestHello/>); expect(screen.getByTestId('hello').textContent).toBe('Hello-Dev'); });
EOF
  else
    cat > "$TEST" <<'EOF'
import React from 'react';
import { render, screen } from '@testing-library/react';
import TestHello from './__TestHello__';
test('renders Hello-Dev', () => { render(<TestHello/>); expect(screen.getByTestId('hello').textContent).toBe('Hello-Dev'); });
EOF
  fi
fi
# verify testing libs present in package.json
for pkg in "@testing-library/react" "@testing-library/jest-dom"; do
  if ! jq -e ".dependencies[\"$pkg\"]? or .devDependencies[\"$pkg\"]?" package.json >/dev/null; then
    echo "ERROR: required testing package $pkg missing in package.json" >&2; exit 3
  fi
done
# run tests; capture output to log for visibility
export CI=true
# Prefer npm if available (container has npm). Run tests in non-watch CI-friendly mode.
if ! command -v npm >/dev/null 2>&1; then echo "ERROR: npm not found" >&2; exit 11; fi
npm test -- --watchAll=false --runInBand 2>&1 | tee /tmp/frontend_test.log
TEST_RC=${PIPESTATUS[0]}
if [ "$TEST_RC" -ne 0 ]; then echo "ERROR: tests failed, see /tmp/frontend_test.log" >&2; exit $TEST_RC; fi
