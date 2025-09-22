#!/usr/bin/env bash
set -euo pipefail
# Start script wrapper (idempotent) — starts dev server in foreground for debugging if needed
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
PORT=${PORT:-3000}
export NODE_ENV=development
export CI=true
export BROWSER=none
npm run start
