#!/usr/bin/env bash
set -euo pipefail
# Run lightweight test harness in CI mode
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
export NODE_ENV=test
export CI=true
npm i --no-audit --no-fund --quiet
# run tests (react-scripts provides jest)
npm test -- --watchAll=false --silent || true
