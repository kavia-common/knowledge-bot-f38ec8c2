#!/usr/bin/env bash
set -euo pipefail
# Validation driver for devserver readiness (uses workspace from container context)
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
PORT=${PORT:-3000}
export NODE_ENV=development
export CI=true
export BROWSER=none
LOGFILE=$(mktemp -t frontend-dev-logs.XXXX)
# start dev server headlessly and capture logs; record PID
setsid env PORT="$PORT" NODE_ENV="$NODE_ENV" BROWSER=none CI=true npm run start >"$LOGFILE" 2>&1 &
PID=$!
# give process a moment
sleep 1
READY=0
for i in $(seq 1 60); do
  sleep 1
  HTTP=$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/index.html" || echo "000")
  if [ "$HTTP" = "200" ]; then READY=1; break; fi
  if grep -q -E "Compiled successfully|Compiled with warnings|You can now view" "$LOGFILE" 2>/dev/null; then READY=1; break; fi
done
STATUS_CODE=$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/index.html" || echo "000")
SNIPPET=$(curl -sS "http://127.0.0.1:$PORT/index.html" | head -c 512 || true)
echo "EVIDENCE: HTTP_STATUS=$STATUS_CODE"
echo "EVIDENCE_SNIPPET=${SNIPPET}"
echo "--- DEVSERVER LOG (tail) ---"
tail -n 200 "$LOGFILE" || true
# attempt graceful shutdown
kill "$PID" 2>/dev/null || sudo kill "$PID" 2>/dev/null || true
sleep 1
LEFTOVER_PIDS=$(pgrep -f "react-scripts|node .*react-scripts" || true)
if [ -n "$LEFTOVER_PIDS" ]; then
  sudo kill -TERM $LEFTOVER_PIDS 2>/dev/null || true
  sleep 1
  sudo kill -KILL $LEFTOVER_PIDS 2>/dev/null || true
fi
wait "$PID" 2>/dev/null || true
cp "$LOGFILE" /tmp/frontend-dev-logs.last 2>/dev/null || true
rm -f "$LOGFILE"
if [ "$READY" -ne 1 ]; then echo "ERROR: dev server did not become ready" >&2; echo "Log copied to /tmp/frontend-dev-logs.last"; exit 6; fi
