#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/richknowles/AJSender.git"

echo "== AJSender • Git bootstrap =="
command -v git >/dev/null || { echo "git not found"; exit 1; }

# Ensure we are in a git repo… or init it
if [ ! -d .git ]; then
  git init
fi

# Normalize branch to main
git symbolic-ref HEAD refs/heads/main >/dev/null 2>&1 || true

# Minimal identity prompts if unset
git config user.name  >/dev/null || git config user.name  "Richard Knowles"
git config user.email >/dev/null || git config user.email "webmonster@protonmail.com"

# Create or append .gitignore with a curated block
if [ -f .gitignore ]; then
  echo "" >> .gitignore
  echo "# === AJSender ignore block ===" >> .gitignore
else
  echo "# === AJSender ignore block ===" > .gitignore
fi

cat >> .gitignore <<'EOF'
# OS
.DS_Store
Thumbs.db
Icon?
.Spotlight-V100
.Trashes
ehthumbs.db
Desktop.ini

# Editors
.vscode/
.idea/
.history/
*.code-workspace

# Node… JS toolchains
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
.pnpm-debug.log*
.turbo/
.parcel-cache/
.eslintcache
.stylelintcache
*.tsbuildinfo

# Build outputs… caches
dist/
build/
coverage/
.vite/
.next/
.nuxt/
.svelte-kit/
.cache/
.tmp/
tmp/
temp/

# Env and secrets
.env
.env.*
!.env.example

# Logs… runtime
*.log
logs/
pids/
*.pid
*.pid.lock

# Docker… local data
.docker/
docker-data/
volumes/
data/
db/
*.sqlite
*.sqlite3

# Puppeteer… Chromium… WhatsApp sessions
.puppeteer/
.local-chromium/
chrome-data/
session/
sessions/
whatsapp-server/session/
whatsapp-server/logs/

# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
.pytest_cache/
.mypy_cache/
.coverage

# Misc archives… editor droppings
*.bak
*.tmp
*.swp
*.swo
*.tgz
*.tar
*.tar.gz
*.zip
EOF

# Line endings policy
if [ ! -f .gitattributes ]; then
  echo "* text=auto eol=lf" > .gitattributes
fi

# Make sure we don’t accidentally keep previously tracked junk
git rm -r --cached . >/dev/null 2>&1 || true

# Remote wiring
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

# Stage… commit… push
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit…"
else
  git commit -m "AJSender… initial import with clean .gitignore"
fi

# Create main if missing upstream… then push
git branch -M main
git push -u origin main
echo "== Done… pushed to main at $REPO_URL =="
