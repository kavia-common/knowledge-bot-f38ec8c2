#!/usr/bin/env bash
set -euo pipefail
# Validation: build, start headless dev server, check health, stop
WORKDIR="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WORKDIR"
[ -f package.json ] || { echo 'package.json missing' >&2; exit 18; }
# Verify react-scripts present
node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json')); if(!((p.dependencies&&p.dependencies['react-scripts'])||(p.devDependencies&&p.devDependencies['react-scripts']))) process.exit(1);" >/dev/null 2>&1 || { echo 'react-scripts missing; run deps step' >&2; exit 19; }
# Build production bundle
BUILD_LOG=/tmp/npm-build.log; : > "$BUILD_LOG"; chmod 0644 "$BUILD_LOG"
npm run build --silent >"$BUILD_LOG" 2>&1 || { echo 'build failed' >&2; tail -n 200 "$BUILD_LOG" || true; exit 20; }
# Start dev server headless
START_LOG=/tmp/cra_start.log; : > "$START_LOG"; chmod 0644 "$START_LOG"
PORT=3000
HOST=0.0.0.0
# start in background; set BROWSER=none to prevent opening
HOST="$HOST" PORT="$PORT" BROWSER=none nohup npm start >"$START_LOG" 2>&1 &
STARTER_PID=$!
sleep 1
# Wait for server to bind to PORT
RETRIES=60; COUNT=0; UP=0
while [ $COUNT -lt $RETRIES ]; do
  if command -v ss >/dev/null 2>&1; then
    L=$(ss -ltnp "sport = :$PORT" 2>/dev/null || true)
  else
    L=$(netstat -ltnp 2>/dev/null | grep ":$PORT" || true)
  fi
  if [ -n "$L" ]; then UP=1; break; fi
  sleep 1; COUNT=$((COUNT+1))
done
if [ $UP -ne 1 ]; then echo "dev server not listening on port $PORT after $RETRIES seconds" >&2; tail -n 200 "$START_LOG" || true; # attempt cleanup
  pkill -P "$STARTER_PID" 2>/dev/null || true; kill "$STARTER_PID" 2>/dev/null || true; sleep 1; pkill -9 -f "react-scripts" 2>/dev/null || true; exit 21
fi
# Find the node process(es) actually serving PORT
PIDS=()
if command -v lsof >/dev/null 2>&1; then
  while read -r pid; do PIDS+=("$pid"); done < <(lsof -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null || true)
else
  if command -v ss >/dev/null 2>&1; then
    PIDS_RAW=$(ss -ltnp "sport = :$PORT" 2>/dev/null | awk -F"," '/users:/{for(i=1;i<=NF;i++) if($i~/pid=/) {gsub(/[^0-9]/,"", $i); print $i}}' || true)
    for p in $PIDS_RAW; do PIDS+=("$p"); done
  else
    PIDS_RAW=$(netstat -ltnp 2>/dev/null | grep ":$PORT" | awk -F"/" '{print $1}' | awk '{print $7}' | sed -E 's/[^0-9]//g' || true)
    for p in $PIDS_RAW; do [ -n "$p" ] && PIDS+=("$p"); done
  fi
fi
# Deduplicate
if [ ${#PIDS[@]} -eq 0 ]; then # fallback to starter PID
  PIDS=("$STARTER_PID")
fi
# Print PID evidence
echo "DEV_SERVER_PIDS=${PIDS[*]}"
# Probe HTTP (try localhost and 127.0.0.1)
PROBED=0
for host in 127.0.0.1 localhost; do
  if curl -sS --max-time 2 "http://$host:$PORT/" >/dev/null 2>&1; then PROBED=1; break; fi
done
if [ $PROBED -ne 1 ]; then echo 'dev server not responding to HTTP probe' >&2; tail -n 200 "$START_LOG" || true; fi
# Show recent logs for evidence
echo "--- recent start log (tail -n 100) ---"
tail -n 100 "$START_LOG" || true
# Stop server processes reliably
for p in "${PIDS[@]}"; do
  kill "$p" 2>/dev/null || true
done
sleep 1
for p in "${PIDS[@]}"; do
  if kill -0 "$p" 2>/dev/null; then kill -9 "$p" 2>/dev/null || true; fi
done
# ensure wrapper is gone
kill "$STARTER_PID" 2>/dev/null || true
wait "$STARTER_PID" 2>/dev/null || true
echo 'validation completed'
