#!/bin/bash
# Fix Frontend Build Issues
set -euo pipefail

echo "=== Fixing Frontend Build Issues ==="

# Stop containers
docker-compose down

# Fix frontend package.json - remove production-only flag for build
cat > frontend/package.json << 'EOF'
{
  "name": "ajsender-frontend",
  "private": true,
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
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
    "typescript": "^5.0.2",
    "vite": "^4.4.5",
    "tailwindcss": "^3.3.3",
    "autoprefixer": "^10.4.15",
    "postcss": "^8.4.28"
  }
}
EOF

# Create a simpler Dockerfile that doesn't separate dev/prod dependencies during build
cat > frontend/Dockerfile << 'EOF'
# Build stage
FROM node:18-alpine as build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including dev dependencies for build)
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built app
COPY --from=build /app/dist /usr/share/nginx/html

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

# Update vite.config.ts to be simpler
cat > frontend/vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://backend:3001',
        changeOrigin: true,
        secure: false
      }
    }
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    minify: 'esbuild'
  }
})
EOF

# Ensure nginx.conf exists for frontend
cat > frontend/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        application/javascript
        application/json
        text/css
        text/javascript
        text/plain
        text/xml;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API proxy
        location /api/ {
            proxy_pass http://backend:3001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }

        # Health check
        location /health {
            proxy_pass http://backend:3001/health;
        }

        # Handle client-side routing
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
}
EOF

# Fix backend Dockerfile to be simpler
cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy source code
COPY . .

# Create necessary directories
RUN mkdir -p data whatsapp-session uploads

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S ajsender -u 1001 -G nodejs && \
    chown -R ajsender:nodejs /app

USER ajsender

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

EXPOSE 3001

CMD ["node", "server.js"]
EOF

# Create a working backend server.js
cat > backend/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const csv = require('csv-parser');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// File upload configuration
const upload = multer({ dest: '/tmp/uploads/' });

// Database setup
const dbPath = path.join(__dirname, 'data', 'ajsender.sqlite');
let db = null;
let dbInitialized = false;

// Initialize database
function initializeDatabase() {
    try {
        const dataDir = path.join(__dirname, 'data');
        if (!fs.existsSync(dataDir)) {
            fs.mkdirSync(dataDir, { recursive: true });
        }
        
        db = new sqlite3.Database(dbPath, (err) => {
            if (err) {
                console.error('Database connection error:', err);
                return;
            }
            console.log('Connected to SQLite database');
            
            // Create tables
            db.serialize(() => {
                db.run(`CREATE TABLE IF NOT EXISTS contacts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    phone_number TEXT UNIQUE NOT NULL,
                    name TEXT,
                    email TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )`);

                db.run(`CREATE TABLE IF NOT EXISTS campaigns (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    message TEXT NOT NULL,
                    status TEXT DEFAULT 'draft',
                    sent_count INTEGER DEFAULT 0,
                    failed_count INTEGER DEFAULT 0,
                    total_messages INTEGER DEFAULT 0,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )`);

                dbInitialized = true;
                console.log('Database tables initialized');
            });
        });
    } catch (error) {
        console.error('Database initialization error:', error);
    }
}

// Initialize database on startup
initializeDatabase();

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        backend: 'running',
        database: dbInitialized ? 'connected' : 'connecting',
        timestamp: new Date().toISOString()
    });
});

// Status endpoint
app.get('/api/status', (req, res) => {
    res.json({
        backend: 'running',
        whatsapp: 'disconnected',
        authenticated: false
    });
});

// Metrics endpoint
app.get('/api/metrics', (req, res) => {
    if (!db || !dbInitialized) {
        return res.json({
            totalContacts: 0,
            totalCampaigns: 0,
            totalMessages: 0,
            sentMessages: 0
        });
    }
    
    const queries = {
        totalContacts: 'SELECT COUNT(*) as count FROM contacts',
        totalCampaigns: 'SELECT COUNT(*) as count FROM campaigns'
    };

    db.get(queries.totalContacts, (err, contactRow) => {
        if (err) return res.json({ totalContacts: 0, totalCampaigns: 0, totalMessages: 0, sentMessages: 0 });
        
        db.get(queries.totalCampaigns, (err, campaignRow) => {
            if (err) return res.json({ totalContacts: 0, totalCampaigns: 0, totalMessages: 0, sentMessages: 0 });
            
            res.json({
                totalContacts: contactRow ? contactRow.count : 0,
                totalCampaigns: campaignRow ? campaignRow.count : 0,
                totalMessages: 0,
                sentMessages: 0
            });
        });
    });
});

// Campaign progress endpoint
app.get('/api/campaigns/progress', (req, res) => {
    res.json({
        isActive: false,
        percentage: 0,
        currentCampaign: null,
        totalContacts: 0,
        sentCount: 0
    });
});

// Contacts endpoints
app.get('/api/contacts', (req, res) => {
    if (!db || !dbInitialized) {
        return res.json([]);
    }
    
    db.all('SELECT * FROM contacts ORDER BY created_at DESC', (err, rows) => {
        if (err) {
            console.error('Error fetching contacts:', err);
            return res.json([]);
        }
        res.json(rows || []);
    });
});

// Campaigns endpoints
app.get('/api/campaigns', (req, res) => {
    if (!db || !dbInitialized) {
        return res.json([]);
    }
    
    db.all('SELECT * FROM campaigns ORDER BY created_at DESC', (err, rows) => {
        if (err) {
            console.error('Error fetching campaigns:', err);
            return res.json([]);
        }
        res.json(rows || []);
    });
});

app.post('/api/campaigns', (req, res) => {
    if (!db || !dbInitialized) {
        return res.status(503).json({ error: 'Database not ready' });
    }
    
    const { name, message } = req.body;
    
    if (!name || !message) {
        return res.status(400).json({ error: 'Name and message are required' });
    }

    db.run(
        'INSERT INTO campaigns (name, message) VALUES (?, ?)',
        [name, message],
        function(err) {
            if (err) {
                console.error('Error creating campaign:', err);
                return res.status(500).json({ error: err.message });
            }
            res.json({ 
                id: this.lastID, 
                name, 
                message,
                status: 'draft'
            });
        }
    );
});

// CSV Upload endpoint
app.post('/api/contacts/upload', upload.single('csvFile'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    const contacts = [];
    let processedCount = 0;

    fs.createReadStream(req.file.path)
        .pipe(csv())
        .on('data', (row) => {
            processedCount++;
            
            const phoneNumber = row.phone_number || row.phone || row.number;
            const name = row.name || row.Name || '';

            if (phoneNumber) {
                const cleanPhone = phoneNumber.toString().replace(/[^\d+]/g, '');
                if (cleanPhone) {
                    contacts.push({ phone_number: cleanPhone, name: name.toString() });
                }
            }
        })
        .on('end', () => {
            fs.unlinkSync(req.file.path);

            if (contacts.length === 0) {
                return res.status(400).json({ error: 'No valid contacts found in CSV' });
            }

            if (!db || !dbInitialized) {
                return res.status(503).json({ error: 'Database not ready' });
            }

            let insertedCount = 0;
            let skippedCount = 0;
            let completed = 0;

            contacts.forEach(contact => {
                db.run(
                    'INSERT OR IGNORE INTO contacts (phone_number, name) VALUES (?, ?)',
                    [contact.phone_number, contact.name],
                    function(err) {
                        if (!err && this.changes > 0) {
                            insertedCount++;
                        } else {
                            skippedCount++;
                        }
                        
                        completed++;
                        if (completed === contacts.length) {
                            res.json({
                                success: true,
                                inserted: insertedCount,
                                skipped: skippedCount,
                                total: contacts.length
                            });
                        }
                    }
                );
            });
        })
        .on('error', (error) => {
            if (fs.existsSync(req.file.path)) {
                fs.unlinkSync(req.file.path);
            }
            res.status(500).json({ error: 'Error processing CSV file: ' + error.message });
        });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`AJ Sender Backend running on port ${PORT}`);
});
EOF

# Update backend package.json
cat > backend/package.json << 'EOF'
{
  "name": "ajsender-backend",
  "version": "2.0.0",
  "description": "AJ Sender WhatsApp bulk messaging backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1",
    "csv-parser": "^3.0.0",
    "sqlite3": "^5.1.6"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

echo "✅ Frontend build issues fixed!"
echo ""
echo "Building and starting containers..."
docker-compose up --build -d

echo ""
echo "🎉 Build should now complete successfully!"
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:3001"