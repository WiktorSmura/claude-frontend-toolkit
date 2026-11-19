#!/usr/bin/env bash
# A minimal React app: one component, no browser tooling.
set -euo pipefail
mkdir -p src
cat > package.json <<'JSON'
{ "name": "demo", "private": true, "dependencies": { "react": "19.0.0", "react-dom": "19.0.0" } }
JSON
printf 'export function App() {\n  return <h1>Welcome</h1>\n}\n' > src/App.tsx
