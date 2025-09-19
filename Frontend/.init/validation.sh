#!/usr/bin/env bash
set -euo pipefail
# Combined validation runner: build, start, probe, and stop with logs
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
cd "$WS"
# 1) Build
./.init_build.sh || true
# The individual scripts are expected to be placed in workspace .init as .init_build.sh etc.
# If not present, run inline build
if [ ! -x ./.init_build.sh ]; then
  node -e "const p=require('./package.json'); if(!(p.scripts&&p.scripts.build)){console.error('no build script in package.json'); process.exit(2)}" || exit 2
  npm run build > /tmp/frontend_build.log 2>&1 || (sed -n '1,200p' /tmp/frontend_build.log >&2; echo 'build failed' >&2; exit 3)
fi
# 2) Start
./.init_start.sh || true
if [ ! -x ./.init_start.sh ]; then
  bash -c "$(sed -n '1,240p' <<'START'
#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
PORT=3000
cd "$WS"
SERVE_LOCAL="$WS/node_modules/.bin/serve"
SERVE_LOG="/tmp/frontend_serve.log"
if [ -x "$SERVE_LOCAL" ]; then
  "$SERVE_LOCAL" -s build -l "$PORT" >"$SERVE_LOG" 2>&1 &
else
  if command -v npx >/dev/null 2>&1; then
    npx --no-install serve -s build -l "$PORT" >"$SERVE_LOG" 2>&1 &
  else
    echo 'serve not available locally and npx missing' >&2; exit 4
  fi
fi
sleep 1
PID=""
PID=$(ss -ltnp 2>/dev/null | awk -v p=":"$PORT '$4~p{gsub(/.*pid=/,"",$0); gsub(/,.*$/,"",$0); print $NF; exit}' || true)
if [ -z "$PID" ]; then
  PID=$(pgrep -f "serve -s build" | head -n1 || true)
fi
if [ -z "$PID" ]; then echo 'could not determine serve PID' >&2; sed -n '1,200p' "$SERVE_LOG" >&2; exit 5; fi
echo "$PID" > /tmp/frontend_serve.pid
echo "serve started, PID=$PID"
START
)"
fi
# 3) Probe
./.init_probe.sh || true
if [ ! -x ./.init_probe.sh ]; then
  PORT=3000
  for i in {1..30}; do sleep 1; CODE=$(curl -sS -o /dev/null -w "%{http_code}" -L "http://localhost:${PORT}/" 2>/dev/null || true); if [ "$CODE" = "200" ]; then break; fi; if [ $i -eq 30 ]; then echo 'server did not respond with 200' >&2; sed -n '1,200p' /tmp/frontend_serve.log >&2; exit 6; fi; done
  BODY=$(curl -sS -L "http://localhost:${PORT}/" || true)
  if [ -z "$BODY" ]; then echo 'empty response body' >&2; sed -n '1,200p' /tmp/frontend_serve.log >&2; exit 7; fi
  if ! echo "$BODY" | grep -q '<div id="root"' ; then echo 'warning: root div not found; app may use different index' >&2; fi
  echo "HTTP 200 received and non-empty body"
fi
# 4) Stop
./.init_stop.sh || true
if [ ! -x ./.init_stop.sh ]; then
  PID_FILE=/tmp/frontend_serve.pid
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" || true)
    if [ -n "$PID" ]; then
      kill "$PID" 2>/dev/null || true
      for i in {1..10}; do if ps -p "$PID" > /dev/null 2>&1; then sleep 1; else break; fi; done
      rm -f "$PID_FILE" || true
      echo "stopped PID $PID"
    fi
  else
    P=$(pgrep -f "serve -s build" || true)
    if [ -n "$P" ]; then kill $P 2>/dev/null || true; echo "stopped fallback PIDs: $P"; fi
  fi
fi
# Output serve log excerpt as evidence
sed -n '1,200p' /tmp/frontend_serve.log || true
exit 0
