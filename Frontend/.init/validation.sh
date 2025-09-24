#!/usr/bin/env bash
set -euo pipefail
# validation - build, serve production bundle, smoke-check, and cleanup
WORKSPACE="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WORKSPACE"
# Ensure package.json exists
if [ ! -f package.json ]; then echo "ERROR: package.json missing" >&2; exit 2; fi
# Build with production env and capture logs
NODE_ENV=production npm run build 2>&1 | tee /tmp/frontend_build.log
if [ ! -d build ] || [ ! -f build/index.html ]; then echo "ERROR: build artifacts missing, see /tmp/frontend_build.log" >&2; exit 3; fi
# Start serve in its own process group on port 5000
PORT=5000
LOG=/tmp/frontend_serve.log
setsid npx --yes serve -s build -l "$PORT" >"$LOG" 2>&1 &
SERVER_PID=$!
# Ensure process group is terminated on exit or signal
trap 'kill -TERM -"$SERVER_PID" >/dev/null 2>&1 || true' EXIT TERM INT
# Wait for HTTP 200 with retries (up to MAX_WAIT seconds)
MAX_WAIT=60
SLEEP=1
i=0
SUCCESS=0
while [ $i -lt $MAX_WAIT ]; do
  if curl -fS -m 5 -o /tmp/frontend_body.html "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
    SUCCESS=1
    break
  fi
  i=$((i+1))
  sleep $SLEEP
done
if [ $SUCCESS -ne 1 ]; then
  echo "ERROR: server did not respond with HTTP 200 within timeout; see $LOG" >&2
  echo "--- serve log ---" >&2
  sed -n '1,200p' "$LOG" >&2 || true
  exit 4
fi
# capture evidence: HTTP status implied by curl success and first 512 bytes
HEAD_SNIPPET=$(head -c 512 /tmp/frontend_body.html | tr -d '\r\n')
# Output a single-line validation success with snippet
echo "VALIDATION_OK: HTTP 200, snippet: ${HEAD_SNIPPET}"
# Clean shutdown of the server process group
kill -TERM -"$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
trap - EXIT TERM INT
