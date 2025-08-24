#!/usr/bin/env bash
# Complete frontend fix - use Vite instead of Create React App
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Complete Frontend Fix - Switching to Vite ==="

# 1. Create new package.json with Vite (much more reliable than CRA)
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
    "vite": "^4.4.0"
  }
}
EOF

# 2. Create Vite config
cat > frontend/vite.config.ts <<'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist'
  },
  server: {
    port: 3000,
    host: true
  }
})
EOF

# 3. Create TypeScript config
cat > frontend/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
EOF

# 4. Create TypeScript config for Node
cat > frontend/tsconfig.node.json <<'EOF'
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
EOF

# 5. Update HTML template
mkdir -p frontend/public
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AJ Sender</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# 6. Update src structure for Vite
mkdir -p frontend/src
cat > frontend/src/main.tsx <<'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Only create App.tsx if it doesn't exist
if [ ! -f frontend/src/App.tsx ]; then
cat > frontend/src/App.tsx <<'EOF'
import React from 'react'
import Dashboard from './components/Dashboard'

function App() {
  return <Dashboard />
}

export default App
EOF
fi

# 7. Ensure components directory exists (preserve existing Dashboard)
mkdir -p frontend/src/components

# Only create a basic Dashboard if none exists
if [ ! -f frontend/src/components/Dashboard.tsx ]; then
cat > frontend/src/components/Dashboard.tsx <<'EOF'
import React, { useState, useEffect } from 'react'
import { Users, MessageSquare, Send, BarChart3, Plus, Upload, CheckCircle, XCircle, X } from 'lucide-react'

const Dashboard: React.FC = () => {
  const [metrics, setMetrics] = useState({
    totalContacts: 0,
    totalCampaigns: 0,
    totalMessages: 0,
    sentMessages: 0
  })

  useEffect(() => {
    // Fetch data from API
    const fetchData = async () => {
      try {
        const response = await fetch('/api/metrics')
        if (response.ok) {
          const data = await response.json()
          setMetrics(data)
        }
      } catch (error) {
        console.error('Error fetching metrics:', error)
      }
    }

    fetchData()
    const interval = setInterval(fetchData, 5000)
    return () => clearInterval(interval)
  }, [])

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <h1 className="text-2xl font-bold text-gray-900">AJ Sender</h1>
          <p className="text-gray-600">WhatsApp Bulk Messaging</p>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Total Contacts</p>
                <p className="text-2xl font-bold">{metrics.totalContacts}</p>
              </div>
              <Users className="w-8 h-8 text-blue-500" />
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Campaigns</p>
                <p className="text-2xl font-bold">{metrics.totalCampaigns}</p>
              </div>
              <MessageSquare className="w-8 h-8 text-green-500" />
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Messages</p>
                <p className="text-2xl font-bold">{metrics.totalMessages}</p>
              </div>
              <Send className="w-8 h-8 text-purple-500" />
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Success Rate</p>
                <p className="text-2xl font-bold">
                  {metrics.totalMessages > 0 ? Math.round((metrics.sentMessages / metrics.totalMessages) * 100) : 0}%
                </p>
              </div>
              <CheckCircle className="w-8 h-8 text-orange-500" />
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-white p-6 rounded-lg shadow cursor-pointer hover:shadow-lg">
            <div className="flex items-center gap-4">
              <Upload className="w-6 h-6 text-gray-700" />
              <div>
                <h3 className="font-semibold">Upload Contacts</h3>
                <p className="text-sm text-gray-600">Import contacts from CSV</p>
              </div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow cursor-pointer hover:shadow-lg">
            <div className="flex items-center gap-4">
              <Plus className="w-6 h-6 text-gray-700" />
              <div>
                <h3 className="font-semibold">Create Campaign</h3>
                <p className="text-sm text-gray-600">Start a new campaign</p>
              </div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow cursor-pointer hover:shadow-lg">
            <div className="flex items-center gap-4">
              <BarChart3 className="w-6 h-6 text-gray-700" />
              <div>
                <h3 className="font-semibold">View Analytics</h3>
                <p className="text-sm text-gray-600">Track performance</p>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

export default Dashboard
EOF
fi

# 8. Create much simpler Dockerfile for Vite build
cat > frontend/Dockerfile <<'EOF'
FROM node:18-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build with Vite
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=build /app/dist /usr/share/nginx/html

# Create nginx config
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

# 9. Clean up old files that might conflict
rm -f frontend/.npmrc
rm -f frontend/nginx-frontend.conf

# 10. Update dockerignore
cat > frontend/.dockerignore <<'EOF'
node_modules
dist
.git
*.log
.DS_Store
EOF

echo "=== Rebuilding with Vite ==="
docker-compose build --no-cache frontend

echo "=== Starting services ==="
docker-compose down
docker-compose up -d

# Wait for services
sleep 15

echo "=== Service Status ==="
docker-compose ps

echo ""
echo "=== Health Checks ==="
echo "Frontend: http://localhost"
echo "Backend health:"
curl -s http://localhost:3001/health 2>/dev/null || echo "Backend not ready yet"

echo ""
echo "Fixed by switching from Create React App to Vite:"
echo "- No more React Scripts dependency conflicts"
echo "- Much faster builds"
echo "- Modern TypeScript support"
echo "- Your existing Dashboard component is preserved"