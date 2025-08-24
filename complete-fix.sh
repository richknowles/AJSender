#!/usr/bin/env bash
# Complete fix for both frontend build and Caddy configuration
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Complete AJ Sender Deployment Fix ==="

# 1. Fix frontend Tailwind dependencies first
echo "Fixing frontend Tailwind CSS dependencies..."

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

cat > frontend/postcss.config.js <<'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

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

cat > frontend/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
EOF

# Ensure main.tsx imports CSS
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

# Remove Tailwind CDN from HTML since we're building it locally
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

# 2. Fix Caddy configuration for local development
echo "Creating local development Caddyfile..."

cat > caddy/Caddyfile <<'EOF'
{
    # Local development - no email needed
    local_certs
}

# Local development setup
localhost {
    encode zstd gzip
    
    # API routes go to backend
    handle_path /api/* {
        reverse_proxy backend:3001
    }
    
    # Auth routes go to backend  
    handle_path /auth/* {
        reverse_proxy backend:3001
    }
    
    # WhatsApp routes (when enabled)
    # handle_path /wa/* {
    #     reverse_proxy whatsapp-server:3002
    # }
    
    # Health check
    handle /health {
        reverse_proxy backend:3001
    }
    
    # Everything else goes to frontend
    handle {
        reverse_proxy frontend:80
    }
}

# Also handle direct IP access
:80 {
    encode zstd gzip
    
    handle_path /api/* {
        reverse_proxy backend:3001
    }
    
    handle_path /auth/* {
        reverse_proxy backend:3001
    }
    
    handle /health {
        reverse_proxy backend:3001
    }
    
    handle {
        reverse_proxy frontend:80
    }
}
EOF

# 3. Create production Caddyfile as backup
cat > caddy/Caddyfile.production <<'EOF'
{
    email admin@alisium.run
}

# Production configuration
sender.ajricardo.com {
    encode zstd gzip
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }
    route {
        handle_path /api/* {
            reverse_proxy backend:3001
        }
        handle_path /auth/* {
            reverse_proxy backend:3001
        }
        handle /health {
            reverse_proxy backend:3001
        }
        handle {
            reverse_proxy frontend:80
        }
    }
}

code.dev.alisium.run {
    encode zstd gzip
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }
    reverse_proxy http://host.docker.internal:8081
}
EOF

# 4. Update docker-compose to include Caddy properly
cat > docker-compose.yml <<'EOF'
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:80"
    networks:
      - ajsender-network
    restart: unless-stopped

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

  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - ajsender-network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:

networks:
  ajsender-network:
    driver: bridge
EOF

echo "=== Building and starting services ==="

# Stop any existing services
docker-compose down --remove-orphans

# Build with no cache to ensure clean build
docker-compose build --no-cache

# Start all services
docker-compose up -d

# Wait for services to start
sleep 15

echo ""
echo "=== Service Status ==="
docker-compose ps

echo ""
echo "=== Health Checks ==="
echo "Testing backend health..."
curl -s http://localhost:3001/health | head -1 2>/dev/null || echo "Backend not ready yet"

echo ""
echo "Testing frontend access..."
curl -s http://localhost:3000 | grep -o '<title>.*</title>' 2>/dev/null || echo "Frontend not ready yet"

echo ""
echo "=== Access Points ==="
echo "🌐 Main Application: http://localhost (via Caddy)"
echo "🎯 Direct Frontend: http://localhost:3000"
echo "⚙️  Direct Backend: http://localhost:3001"
echo "📱 WhatsApp Server: http://localhost:3002"

echo ""
echo "=== What was fixed ==="
echo "✅ Added missing Tailwind CSS dependencies to frontend"
echo "✅ Created proper PostCSS and Tailwind configs"
echo "✅ Fixed CSS imports in main.tsx"
echo "✅ Updated Caddyfile for local development (localhost)"
echo "✅ Created production Caddyfile backup"
echo "✅ Fixed Docker Compose configuration"
echo ""
echo "If you need to deploy to production later, copy caddy/Caddyfile.production"
echo "to caddy/Caddyfile and update your DNS to point to this server."