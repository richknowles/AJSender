#!/usr/bin/env bash
# Quick fix for react-refresh missing dependency
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Fixing React Refresh Dependency ==="

# Update package.json to include react-refresh explicitly
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
    "react-refresh": "^0.11.0",
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

# Update Dockerfile to install all dependencies (including dev deps needed for build)
cat > frontend/Dockerfile <<'EOF'
FROM node:18-alpine AS build
WORKDIR /app

# Copy package files and .npmrc
COPY package*.json .npmrc ./

# Install ALL dependencies (including dev deps) with legacy peer deps
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

echo "=== Rebuilding frontend only ==="
docker-compose build --no-cache frontend

echo "=== Restarting services ==="
docker-compose down
docker-compose up -d

# Wait for services
sleep 15

echo "=== Service Status ==="
docker-compose ps

echo ""
echo "=== Health Checks ==="
echo "Frontend available at: http://localhost"
echo "Backend health:"
curl -s http://localhost:3001/health 2>/dev/null || echo "Backend not ready yet"

echo ""
echo "Fixed: Added react-refresh dependency and ensured dev deps are installed during build"