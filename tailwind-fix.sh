#!/usr/bin/env bash
# Simple Tailwind CSS fix for frontend build
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Fixing Tailwind CSS Missing Dependency ==="

# 1. Update frontend package.json to include Tailwind CSS dependencies
cat > frontend/package.json <<'EOF'
{
  "name": "ajsender-frontend",
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "framer-motion": "^10.16.4",
    "lucide-react": "^0.263.1"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^4.4.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0"
  }
}
EOF

# 2. Create postcss.config.js (not .cjs since package.json has "type": "module")
cat > frontend/postcss.config.js <<'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# 3. Create tailwind.config.js
cat > frontend/tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

# 4. Update the index.html to remove Tailwind CDN since we're building it now
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AJ Sender</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# 5. Create a CSS file that imports Tailwind
cat > frontend/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
EOF

# 6. Update main.tsx to import the CSS file
cat > frontend/src/main.tsx <<'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# 7. Create a simple Dockerfile that installs dependencies properly
cat > frontend/Dockerfile <<'EOF'
FROM node:18-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including Tailwind)
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files to nginx
COPY --from=build /app/dist /usr/share/nginx/html

# Create nginx config for SPA routing
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

echo "=== Building frontend with Tailwind CSS ==="
docker-compose build --no-cache frontend

echo "=== Starting services ==="
docker-compose up -d

sleep 10

echo "=== Service Status ==="
docker-compose ps

echo ""
echo "=== Health Checks ==="
echo "Frontend: http://localhost:3000"
echo "Backend health:"
curl -s http://localhost:3001/health 2>/dev/null || echo "Backend not ready yet"

echo ""
echo "Fixed by:"
echo "- Adding tailwindcss, postcss, and autoprefixer to devDependencies"
echo "- Creating proper PostCSS and Tailwind configs"  
echo "- Setting up CSS imports correctly"
echo "- Using ES modules format consistently"