#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
PORT=3000
cd "$WS"
SERVE_LOCAL="$WS/node_modules/.bin/serve"
SERVE_LOG="/tmp/frontend_serve.log"
# Start server in background (prefer project-local)
if [ -x "$SERVE_LOCAL" ]; then
  "$SERVE_LOCAL" -s build -l "$PORT" >"$SERVE_LOG" 2>&1 &
else
  if command -v npx >/dev/null 2>&1; then
    npx --no-install serve -s build -l "$PORT" >"$SERVE_LOG" 2>&1 &
  else
    echo 'serve not available locally and npx missing' >&2; exit 4
  fi
fi
# Give server a moment to bind
sleep 1
# Discover real PID listening on the port using ss
PID=""
PID=$(ss -ltnp 2>/dev/null | awk -v p=":"$PORT '$4~p{gsub(/.*pid=/,"",$0); gsub(/,.*$/,"",$0); print $NF; exit}' || true)
if [ -z "$PID" ]; then
  PID=$(pgrep -f "serve -s build" | head -n1 || true)
fi
if [ -z "$PID" ]; then
  echo 'could not determine serve PID' >&2; sed -n '1,200p' "$SERVE_LOG" >&2; exit 5
fi
# Persist PID for stop script
echo "$PID" > /tmp/frontend_serve.pid
# Output small evidence
echo "serve started, PID=$PID"
sed -n '1,200p' "$SERVE_LOG" || true
exit 0
