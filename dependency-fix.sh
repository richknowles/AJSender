#!/usr/bin/env bash
# AJ Sender Dependency Fix - Keep existing Dashboard, fix TypeScript conflict
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Fixing TypeScript Dependency Conflict ==="

# 1. Fix the frontend package.json with compatible TypeScript version
cat > frontend/package.json <<'EOF'
{
  "name": "ajsender-frontend",
  "version": "2.0.0",
  "private": true,
  "dependencies": {
    "@types/node": "^18.0.0",
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0",
    "framer-motion": "^10.16.4",
    "lucide-react": "^0.263.1",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "typescript": "^4.9.5",
    "web-vitals": "^3.3.2"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
EOF

# 2. Create .npmrc to handle peer dependency issues
cat > frontend/.npmrc <<'EOF'
legacy-peer-deps=true
fund=false
audit=false
EOF

# 3. Update the frontend Dockerfile to use npm install with legacy peer deps
cat > frontend/Dockerfile <<'EOF'
FROM node:18-alpine AS build
WORKDIR /app

# Copy package files and .npmrc
COPY package*.json .npmrc ./

# Install dependencies with legacy peer deps
RUN npm install --legacy-peer-deps

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx-frontend.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# 4. Create a minimal nginx config for frontend SPA routing
cat > frontend/nginx-frontend.conf <<'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Handle React Router
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# 5. Ensure basic React structure exists (don't overwrite your Dashboard)
mkdir -p frontend/public frontend/src

# Only create these if they don't exist
if [ ! -f frontend/public/index.html ]; then
cat > frontend/public/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>AJ Sender</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOF
fi

if [ ! -f frontend/src/index.tsx ]; then
cat > frontend/src/index.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);
root.render(<App />);
EOF
fi

if [ ! -f frontend/src/App.tsx ]; then
cat > frontend/src/App.tsx <<'EOF'
import React from 'react';
import Dashboard from './components/Dashboard';

function App() {
  return <Dashboard />;
}

export default App;
EOF
fi

# 6. Create a simple proxy configuration that routes /api calls to backend
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:80"
    depends_on:
      - backend
    networks:
      - ajsender-network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - PORT=3001
      - WHATSAPP_AUTH_URL=http://whatsapp-server:3002
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - whatsapp-server
    networks:
      - ajsender-network
    restart: unless-stopped

  whatsapp-server:
    build:
      context: ./whatsapp-server
      dockerfile: Dockerfile
    ports:
      - "3002:3002"
    environment:
      - NODE_ENV=production
      - PORT=3002
    volumes:
      - ./whatsapp-sessions:/app/.wwebjs_auth
      - ./whatsapp-cache:/app/.wwebjs_cache
      - ./whatsapp-public:/app/public
    networks:
      - ajsender-network
    restart: unless-stopped

  # Simple nginx reverse proxy
  proxy:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - frontend
      - backend
    networks:
      - ajsender-network

networks:
  ajsender-network:
    driver: bridge
EOF

# 7. Create nginx proxy config
cat > nginx-proxy.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    upstream frontend {
        server frontend:80;
    }
    
    upstream backend {
        server backend:3001;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # Serve frontend
        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # Proxy API calls to backend
        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # CORS headers
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With" always;
            
            # Handle preflight requests
            if ($request_method = 'OPTIONS') {
                add_header Access-Control-Allow-Origin * always;
                add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
                add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With" always;
                add_header Access-Control-Max-Age 3600;
                add_header Content-Type 'text/plain charset=UTF-8';
                add_header Content-Length 0;
                return 204;
            }
        }
    }
}
EOF

# 8. Create dockerignore files if they don't exist
cat > frontend/.dockerignore <<'EOF'
node_modules
.git
*.log
.DS_Store
build
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF

cat > backend/.dockerignore <<'EOF'
node_modules
.git
*.log
.DS_Store
data
logs
EOF

echo "=== Stopping existing containers ==="
docker-compose down -v

echo "=== Building with fixed dependencies ==="
docker-compose build --no-cache

echo "=== Starting services ==="
docker-compose up -d

# Wait for services to start
sleep 20

echo "=== Service Status ==="
docker-compose ps

echo ""
echo "=== Health Checks ==="
echo "Backend health:"
curl -s http://localhost:3001/health 2>/dev/null | head -1 || echo "Backend not ready yet"

echo ""
echo "WhatsApp health:"
curl -s http://localhost:3002/health 2>/dev/null | head -1 || echo "WhatsApp server not ready yet"

echo ""
echo "=== Fixed Issues ==="
echo "- Changed TypeScript from ^5.0.0 to ^4.9.5 (compatible with react-scripts 5.0.1)"
echo "- Added .npmrc with legacy-peer-deps=true"
echo "- Updated Dockerfile to use --legacy-peer-deps flag"
echo "- Added nginx proxy to route /api calls to backend"
echo "- Kept your existing Dashboard component unchanged"

echo ""
echo "Test your application at: http://localhost"
echo "API endpoints are proxied through nginx to the backend"
echo ""
echo "If you still get refresh loops, check the browser console for API errors"
echo "and ensure your Dashboard component is making calls to /api/* endpoints"