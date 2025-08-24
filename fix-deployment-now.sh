#!/usr/bin/env bash
# Fix Deployment Issues - ARM64 compatibility and Puppeteer
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Fixing Deployment Issues ==="

# Stop any running containers
docker-compose down

# Update package.json to fix Puppeteer ARM64 issues
cat > backend/package.json << 'EOF'
{
  "name": "aj-sender-backend",
  "version": "2.0.0",
  "description": "WhatsApp Bulk Messaging Backend",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "build": "echo 'No build step required'",
    "test": "echo 'No tests specified'"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "sqlite3": "^5.1.6",
    "multer": "^1.4.5-lts.1",
    "csv-parser": "^3.0.0",
    "whatsapp-web.js": "^1.25.0",
    "qrcode": "^1.5.3",
    "dotenv": "^16.3.1",
    "express-rate-limit": "^6.8.1",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# Create a new Dockerfile for backend that handles ARM64
cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

# Install system dependencies for Puppeteer and Chromium
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    python3 \
    make \
    g++

# Set environment variables for Puppeteer
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev --force

# Copy source code
COPY . .

# Create necessary directories
RUN mkdir -p data uploads whatsapp-session

# Set permissions
RUN addgroup -g 1001 -S nodejs && \
    adduser -S ajsender -u 1001 -G nodejs && \
    chown -R ajsender:nodejs /app

USER ajsender

EXPOSE 3001

CMD ["npm", "start"]
EOF

# Complete the WhatsApp service file
cat > backend/src/services/whatsapp.js << 'EOF'
const { Client, LocalAuth } = require('whatsapp-web.js')
const qrcode = require('qrcode')
const path = require('path')
const db = require('../models/database')

class WhatsAppService {
  constructor() {
    this.client = null
    this.status = {
      authenticated: false,
      ready: false,
      connected: false,
      status: 'disconnected',
      qrCode: null,
      phoneNumber: null,
      userName: null,
      expired: false
    }
    this.campaignProgress = {
      isActive: false,
      percentage: 0,
      currentCampaign: null,
      totalContacts: 0,
      sentCount: 0
    }
    this.currentCampaignId = null
    this.sendQueue = []
    this.isProcessingQueue = false
  }

  async connect() {
    try {
      if (this.client) {
        await this.disconnect()
      }

      console.log('🔄 Initializing WhatsApp client...')
      
      this.client = new Client({
        authStrategy: new LocalAuth({
          dataPath: path.join(__dirname, '../../whatsapp-session')
        }),
        puppeteer: {
          headless: true,
          executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser',
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--single-process',
            '--disable-gpu',
            '--disable-web-security',
            '--disable-features=VizDisplayCompositor'
          ]
        }
      })

      this.setupEventHandlers()
      
      await this.client.initialize()
      
      return { success: true, message: 'WhatsApp client initialized' }
    } catch (error) {
      console.error('WhatsApp connection error:', error)
      this.status.status = 'error'
      throw error
    }
  }

  setupEventHandlers() {
    this.client.on('qr', async (qr) => {
      try {
        console.log('📱 QR Code received, generating image...')
        this.status.qrCode = await qrcode.toDataURL(qr)
        this.status.status = 'qr_received'
        this.status.expired = false
        console.log('✅ QR Code generated successfully')
      } catch (error) {
        console.error('Error generating QR code:', error)
      }
    })

    this.client.on('authenticated', (session) => {
      console.log('✅ WhatsApp authenticated successfully')
      this.status.authenticated = true
      this.status.qrCode = null
      this.status.status = 'authenticated'
    })

    this.client.on('auth_failure', (msg) => {
      console.error('❌ WhatsApp authentication failed:', msg)
      this.status.authenticated = false
      this.status.status = 'auth_failed'
      this.status.expired = true
    })

    this.client.on('ready', async () => {
      console.log('🚀 WhatsApp client is ready!')
      this.status.ready = true
      this.status.connected = true
      this.status.status = 'ready'
      
      try {
        const info = this.client.info
        this.status.phoneNumber = info.wid.user
        this.status.userName = info.pushname || 'Unknown'
        console.log(`📞 Connected as: ${this.status.userName} (${this.status.phoneNumber})`)
      } catch (error) {
        console.error('Error getting client info:', error)
      }
    })

    this.client.on('disconnected', (reason) => {
      console.log('📱 WhatsApp client disconnected:', reason)
      this.status.authenticated = false
      this.status.ready = false
      this.status.connected = false
      this.status.status = 'disconnected'
      this.status.qrCode = null
      this.status.phoneNumber = null
      this.status.userName = null
    })

    this.client.on('message', (message) => {
      // Handle incoming messages if needed
      console.log('📨 Received message:', message.body.substring(0, 50))
    })
  }

  async disconnect() {
    if (this.client) {
      try {
        await this.client.destroy()
        console.log('📱 WhatsApp client disconnected')
      } catch (error) {
        console.error('Error disconnecting WhatsApp:', error)
      }
      this.client = null
    }
    
    this.status = {
      authenticated: false,
      ready: false,
      connected: false,
      status: 'disconnected',
      qrCode: null,
      phoneNumber: null,
      userName: null,
      expired: false
    }
  }

  getStatus() {
    return { ...this.status }
  }

  getCampaignProgress() {
    return { ...this.campaignProgress }
  }

  async sendCampaign(campaignId) {
    try {
      console.log(`🚀 Starting campaign ${campaignId}`)
      
      if (!this.status.ready) {
        throw new Error('WhatsApp not ready')
      }

      const campaign = await db.getCampaign(campaignId)
      if (!campaign) {
        throw new Error('Campaign not found')
      }

      const contacts = await db.getAllContacts()
      if (contacts.length === 0) {
        throw new Error('No contacts found')
      }

      // Update campaign status
      await db.updateCampaignStatus(campaignId, 'sending')

      // Initialize progress
      this.campaignProgress = {
        isActive: true,
        percentage: 0,
        currentCampaign: campaign.name,
        totalContacts: contacts.length,
        sentCount: 0
      }

      // Create message records
      for (const contact of contacts) {
        await db.createMessage(campaignId, contact.id, contact.phone_number, campaign.message)
      }

      // Start sending process
      this.currentCampaignId = campaignId
      await this.processCampaignMessages(campaignId, campaign.message, contacts)

    } catch (error) {
      console.error('Error sending campaign:', error)
      if (campaignId) {
        await db.updateCampaignStatus(campaignId, 'failed')
      }
      this.campaignProgress.isActive = false
      throw error
    }
  }

  async processCampaignMessages(campaignId, message, contacts) {
    let sentCount = 0
    let failedCount = 0

    for (let i = 0; i < contacts.length; i++) {
      const contact = contacts[i]
      
      try {
        // Format phone number
        let phoneNumber = contact.phone_number.replace(/\D/g, '')
        if (!phoneNumber.startsWith('1') && phoneNumber.length === 10) {
          phoneNumber = '1' + phoneNumber
        }
        
        const chatId = phoneNumber + '@c.us'
        
        // Send message
        await this.client.sendMessage(chatId, message)
        
        // Update message status
        const messageRecord = await this.getMessageRecord(campaignId, contact.id)
        if (messageRecord) {
          await db.updateMessageStatus(messageRecord.id, 'sent')
        }
        
        sentCount++
        console.log(`✅ Sent message to ${phoneNumber}`)
        
      } catch (error) {
        console.error(`❌ Failed to send message to ${contact.phone_number}:`, error.message)
        
        // Update message status with error
        const messageRecord = await this.getMessageRecord(campaignId, contact.id)
        if (messageRecord) {
          await db.updateMessageStatus(messageRecord.id, 'failed', error.message)
        }
        
        failedCount++
      }

      // Update progress
      this.campaignProgress.sentCount = sentCount
      this.campaignProgress.percentage = Math.round(((sentCount + failedCount) / contacts.length) * 100)

      // Add delay between messages to avoid rate limiting
      if (i < contacts.length - 1) {
        await this.delay(2000) // 2 second delay
      }
    }

    // Update campaign final status
    const finalStatus = failedCount === 0 ? 'completed' : 'completed_with_errors'
    await db.updateCampaignStatus(campaignId, finalStatus, sentCount, failedCount)

    // Reset progress
    this.campaignProgress.isActive = false
    this.currentCampaignId = null

    console.log(`🎉 Campaign ${campaignId} completed: ${sentCount} sent, ${failedCount} failed`)
  }

  async getMessageRecord(campaignId, contactId) {
    return new Promise((resolve, reject) => {
      db.db.get(
        'SELECT * FROM messages WHERE campaign_id = ? AND contact_id = ?',
        [campaignId, contactId],
        (err, row) => {
          if (err) reject(err)
          else resolve(row)
        }
      )
    })
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}

// Create singleton instance
const whatsappService = new WhatsAppService()

module.exports = whatsappService
EOF

# Create environment file for backend
cat > backend/.env << 'EOF'
NODE_ENV=production
PORT=3001
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
DATABASE_URL=sqlite:///app/data/database.sqlite
WHATSAPP_SESSION_PATH=/app/whatsapp-session
EOF

# Update frontend Dockerfile to use proper build context
cat > frontend/Dockerfile << 'EOF'
# Build stage
FROM node:18-alpine as build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=build /app/dist /usr/share/nginx/html

# Create nginx configuration
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/ { \
        proxy_pass http://backend:3001/api/; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# Create basic frontend package.json if it doesn't exist
mkdir -p frontend/src/components
if [ ! -f "frontend/package.json" ]; then
    cat > frontend/package.json << 'EOF'
{
  "name": "aj-sender-frontend",
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "lucide-react": "^0.263.1"
  },
  "devDependencies": {
    "@types/react": "^18.2.15",
    "@types/react-dom": "^18.2.7",
    "@vitejs/plugin-react": "^4.0.3",
    "autoprefixer": "^10.4.14",
    "postcss": "^8.4.27",
    "tailwindcss": "^3.3.3",
    "typescript": "^5.0.2",
    "vite": "^4.4.5"
  }
}
EOF
fi

# Create vite.config.ts if it doesn't exist
if [ ! -f "frontend/vite.config.ts" ]; then
    cat > frontend/vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://backend:3001',
        changeOrigin: true
      }
    }
  },
  build: {
    outDir: 'dist'
  }
})
EOF
fi

# Create App.tsx if it doesn't exist
if [ ! -f "frontend/src/App.tsx" ]; then
    cat > frontend/src/App.tsx << 'EOF'
import Dashboard from './components/Dashboard'
import './index.css'

function App() {
  return <Dashboard />
}

export default App
EOF
fi

# Create main.tsx if it doesn't exist  
if [ ! -f "frontend/src/main.tsx" ]; then
    cat > frontend/src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF
fi

# Create index.html if it doesn't exist
if [ ! -f "frontend/index.html" ]; then
    cat > frontend/index.html << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AJ Sender - WhatsApp Bulk Messaging</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF
fi

# Create CSS file if it doesn't exist
if [ ! -f "frontend/src/index.css" ]; then
    cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
EOF
fi

# Create tailwind.config.js if it doesn't exist
if [ ! -f "frontend/tailwind.config.js" ]; then
    cat > frontend/tailwind.config.js << 'EOF'
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
fi

# Create tsconfig.json if it doesn't exist
if [ ! -f "frontend/tsconfig.json" ]; then
    cat > frontend/tsconfig.json << 'EOF'
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
fi

# Create tsconfig.node.json if it doesn't exist
if [ ! -f "frontend/tsconfig.node.json" ]; then
    cat > frontend/tsconfig.node.json << 'EOF'
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
fi

echo "✅ Fixed deployment configuration!"
echo ""
echo "=== Building and Starting Application ==="
docker-compose up --build -d

echo ""
echo "🎉 AJ Sender deployment completed!"
echo ""
echo "📱 Application URLs:"
echo "   Frontend: http://localhost:3000"
echo "   Backend:  http://localhost:3001"
echo "   Health:   http://localhost:3001/health"
echo ""
echo "🔧 Management Commands:"
echo "   View logs:     docker-compose logs -f"
echo "   View backend:  docker-compose logs -f backend"
echo "   Stop app:      docker-compose down"
echo "   Restart:       docker-compose restart"
echo ""
echo "✨ Your WhatsApp bulk messaging application is ready!"
echo "   1. Upload contacts via CSV"
echo "   2. Connect WhatsApp by scanning QR code"  
echo "   3. Create and send campaigns"
echo ""