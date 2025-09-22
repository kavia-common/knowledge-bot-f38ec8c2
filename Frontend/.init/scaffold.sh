#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/knowledge-bot-f38ec8c2/Frontend"
mkdir -p "$WS" && cd "$WS"
# create minimal package.json if missing
if [ ! -f package.json ]; then
  cat >package.json <<'JSON'
{
  "name": "frontend",
  "version": "0.1.0",
  "private": true,
  "engines": { "node": ">=18" },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "^5.0.1"
  }
}
JSON
fi
mkdir -p public src
# minimal index.html used as liveness (/index.html)
if [ ! -f public/index.html ]; then cat >public/index.html <<'HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Frontend</title></head>
  <body><div id="root"></div></body>
</html>
HTML
fi
if [ ! -f src/index.js ]; then cat >src/index.js <<'JS'
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
const root = createRoot(document.getElementById('root'));
root.render(<App/>);
JS
fi
if [ ! -f src/App.js ]; then cat >src/App.js <<'JS'
import React from 'react';
export default function App(){return React.createElement('div',null,'Knowledge Bot Frontend (dev)');}
JS
fi
# generate package-lock for deterministic installs if missing
if [ ! -f package-lock.json ]; then npm i --package-lock-only --no-audit --no-fund >/dev/null; fi
