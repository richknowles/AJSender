#!/usr/bin/env bash
# AJ Sender deployment script — header
set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "❌ Error: \"${BASH_COMMAND}\" failed at line ${LINENO}" >&2' ERR

# Ensure we're running under bash (avoids fish/zsh heredoc issues)
if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Please run this script with bash:  bash $0" >&2
  exit 1
fi

# Work from the directory this script lives in (repo root)
cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# RK and ChatGPT Patch - 08-24-2025
# --- FIX: Robust Vite/TS frontend Dockerfile (multi-stage) ---
mkdir -p frontend

cat > frontend/Dockerfile <<'EOF'
# --- Build stage ---
FROM node:18-alpine AS build
WORKDIR /app

# install ALL deps (incl dev) so tsc/vite are present
COPY package*.json ./
RUN npm ci

# copy source and build
COPY . .
# harden bin perms to avoid "tsc: Permission denied" in some envs
RUN chmod -R a+rx node_modules/.bin
RUN npm run build

# --- Runtime stage (serve static) ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
EOF

# --- FIX: Don't copy host node_modules into the image ---
cat > frontend/.dockerignore <<'EOF'
node_modules
dist
.git
Dockerfile
EOF

# Docker Compose v1/v2 compatibility (lets the rest of the script use `docker-compose`)
if ! command -v docker-compose >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  shopt -s expand_aliases
  alias docker-compose='docker compose'
fi

# Quick dependency check
for bin in docker docker-compose curl; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Missing dependency: $bin" >&2; exit 1; }
done

# jq is optional (used only for pretty-printing JSON in health checks)
command -v jq >/dev/null 2>&1 || echo "ℹ️  jq not found; health JSON will be unformatted."

set -euo pipefail

echo "== AJ Sender WhatsApp integration setup =="

# --- backend/server.js --------------------------------------------------------
mkdir -p backend
cat > backend/server.js <<'WHATSAPP_INTEGRATED_BACKEND'
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const csv = require('csv-parser');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3001;
const WHATSAPP_AUTH_URL = process.env.WHATSAPP_AUTH_URL || 'http://whatsapp-server:3002';

// Middleware
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:3001', 'https://sender.ajricardo.com'],
  credentials: true
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// File upload configuration
const upload = multer({ 
  dest: '/tmp/uploads/',
  limits: { fileSize: 10 * 1024 * 1024 }
});

// Database and state
let db = null;
let dbInitialized = false;

// Campaign progress tracking
let campaignProgress = {
  isActive: false,
  percentage: 0,
  currentCampaign: null,
  totalContacts: 0,
  sentCount: 0
};

// WhatsApp state
let whatsappStatus = {
  connected: false,
  sessionId: null,
  qrCode: null,
  authenticated: false,
  phoneNumber: null,
  userName: null
};

// Initialize SQLite database
function initializeDatabase() {
  return new Promise((resolve, reject) => {
    try {
      const dataDir = path.join(__dirname, 'data');
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
        console.log('Created data directory');
      }
      
      const dbPath = path.join(dataDir, 'ajsender.sqlite');
      console.log('Initializing database at:', dbPath);
      
      db = new sqlite3.Database(dbPath, sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE, (err) => {
        if (err) {
          console.error('Database connection error:', err);
          reject(err);
          return;
        }
        console.log('Connected to SQLite database');
        
        db.run('PRAGMA foreign_keys = ON');
        db.run('PRAGMA journal_mode = WAL');
        
        db.serialize(() => {
          db.run(`CREATE TABLE IF NOT EXISTS contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT UNIQUE NOT NULL,
            name TEXT DEFAULT '',
            email TEXT DEFAULT '',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )`, (err) => {
            if (err) console.error('Error creating contacts table:', err);
          });

          db.run(`CREATE TABLE IF NOT EXISTS campaigns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            message TEXT NOT NULL,
            status TEXT DEFAULT 'draft',
            total_contacts INTEGER DEFAULT 0,
            sent_count INTEGER DEFAULT 0,
            failed_count INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )`, (err) => {
            if (err) console.error('Error creating campaigns table:', err);
          });

          db.run(`CREATE TABLE IF NOT EXISTS campaign_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            campaign_id INTEGER NOT NULL,
            contact_id INTEGER,
            phone_number TEXT NOT NULL,
            message TEXT NOT NULL,
            status TEXT DEFAULT 'pending',
            error_message TEXT,
            sent_at DATETIME,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (campaign_id) REFERENCES campaigns (id) ON DELETE CASCADE,
            FOREIGN KEY (contact_id) REFERENCES contacts (id) ON DELETE SET NULL
          )`, (err) => {
            if (err) {
              console.error('Error creating campaign_messages table:', err);
              reject(err);
            } else {
              dbInitialized = true;
              console.log('Database initialization completed');
              resolve();
            }
          });
        });
      });
    } catch (error) {
      console.error('Database initialization error:', error);
      reject(error);
    }
  });
}

// WhatsApp API communication functions
async function createWhatsAppSession() {
  try {
    const response = await axios.post(`${WHATSAPP_AUTH_URL}/api/session/create`, {}, {
      timeout: 30000
    });
    return response.data;
  } catch (error) {
    console.error('Failed to create WhatsApp session:', error.message);
    throw error;
  }
}

async function getWhatsAppSessionStatus(sessionId) {
  try {
    const response = await axios.get(`${WHATSAPP_AUTH_URL}/api/session/${sessionId}/status`, {
      timeout: 10000
    });
    return response.data;
  } catch (error) {
    console.error('Failed to get WhatsApp session status:', error.message);
    throw error;
  }
}

async function sendWhatsAppMessage(sessionId, phoneNumber, message) {
  try {
    const response = await axios.post(`${WHATSAPP_AUTH_URL}/api/session/${sessionId}/send`, {
      phoneNumber,
      message
    }, {
      timeout: 15000
    });
    return response.data;
  } catch (error) {
    console.error('Failed to send WhatsApp message:', error.message);
    throw error;
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    backend: 'running',
    database: dbInitialized ? 'connected' : 'connecting',
    whatsapp: whatsappStatus.authenticated ? 'authenticated' : 'disconnected',
    timestamp: new Date().toISOString(),
    version: '2.0.0'
  });
});

// System status endpoint
app.get('/api/status', (req, res) => {
  res.json({
    backend: 'running',
    whatsapp: whatsappStatus.authenticated ? 'authenticated' : 'disconnected',
    authenticated: whatsappStatus.authenticated,
    database: dbInitialized ? 'connected' : 'connecting',
    sessionId: whatsappStatus.sessionId,
    phoneNumber: whatsappStatus.phoneNumber,
    userName: whatsappStatus.userName
  });
});

// Campaign progress endpoint
app.get('/api/campaigns/progress', (req, res) => {
  res.json(campaignProgress);
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
    totalCampaigns: 'SELECT COUNT(*) as count FROM campaigns',
    totalMessages: 'SELECT COUNT(*) as count FROM campaign_messages',
    sentMessages: 'SELECT COUNT(*) as count FROM campaign_messages WHERE status = "sent"'
  };

  const results = {};
  let completedQueries = 0;

  Object.keys(queries).forEach(key => {
    db.get(queries[key], (err, row) => {
      if (err) {
        console.error(`Error executing ${key} query:`, err);
        results[key] = 0;
      } else {
        results[key] = row ? row.count : 0;
      }
      
      completedQueries++;
      if (completedQueries === Object.keys(queries).length) {
        res.json(results);
      }
    });
  });
});

// Contacts endpoints
app.get('/api/contacts', (req, res) => {
  if (!db || !dbInitialized) {
    return res.json([]);
  }
  
  const limit = parseInt(req.query.limit) || 100;
  const offset = parseInt(req.query.offset) || 0;
  
  db.all(
    'SELECT * FROM contacts ORDER BY created_at DESC LIMIT ? OFFSET ?', 
    [limit, offset], 
    (err, rows) => {
      if (err) {
        console.error('Error fetching contacts:', err);
        return res.status(500).json({ error: 'Failed to fetch contacts' });
      }
      res.json(rows || []);
    }
  );
});

app.post('/api/contacts', (req, res) => {
  if (!db || !dbInitialized) {
    return res.status(503).json({ error: 'Database not ready' });
  }
  
  const { phone_number, name, email } = req.body;
  
  if (!phone_number) {
    return res.status(400).json({ error: 'Phone number is required' });
  }

  const cleanPhone = phone_number.replace(/[^\d+]/g, '');

  db.run(
    'INSERT OR REPLACE INTO contacts (phone_number, name, email, updated_at) VALUES (?, ?, ?, ?)',
    [cleanPhone, name || '', email || '', new Date().toISOString()],
    function(err) {
      if (err) {
        console.error('Error inserting contact:', err);
        return res.status(500).json({ error: err.message });
      }
      res.json({ 
        id: this.lastID, 
        phone_number: cleanPhone, 
        name: name || '',
        email: email || '',
        message: 'Contact saved successfully' 
      });
    }
  );
});

// CSV Upload endpoint
app.post('/api/contacts/upload', upload.single('csvFile'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No CSV file uploaded' });
  }

  if (!db || !dbInitialized) {
    return res.status(503).json({ error: 'Database not ready' });
  }

  const contacts = [];
  const errors = [];
  let processedCount = 0;

  console.log(`Processing CSV file: ${req.file.originalname}, size: ${req.file.size} bytes`);

  fs.createReadStream(req.file.path)
    .pipe(csv({
      skipEmptyLines: true,
      headers: (headers) => headers.map(h => h.toLowerCase().trim())
    }))
    .on('data', (row) => {
      processedCount++;
      
      const phoneNumber = row.phone_number || row.phone || row.number || 
                          row.phonenumber || row.mobile || row.cell || 
                          row['phone number'] || row['mobile number'];
      
      const name = row.name || row.first_name || row.firstname || 
                   row.full_name || row.fullname || row['full name'] || 
                   row['first name'] || '';
      
      const email = row.email || row.email_address || row['email address'] || '';

      if (phoneNumber) {
        const cleanPhone = phoneNumber.toString().replace(/[^\d+]/g, '');
        if (cleanPhone && cleanPhone.length >= 10) {
          contacts.push({ 
            phone_number: cleanPhone, 
            name: name.toString().trim(),
            email: email.toString().trim()
          });
        } else {
          errors.push(`Row ${processedCount}: Invalid phone number format: "${phoneNumber}"`);
        }
      } else {
        errors.push(`Row ${processedCount}: Missing phone number`);
      }
    })
    .on('end', () => {
      fs.unlinkSync(req.file.path);

      if (contacts.length === 0) {
        return res.status(400).json({ 
          error: 'No valid contacts found in CSV',
          errors,
          hint: 'CSV should have columns: phone_number (or phone), name (optional), email (optional)'
        });
      }

      console.log(`Parsed ${contacts.length} valid contacts from CSV`);

      let insertedCount = 0;
      let skippedCount = 0;
      let completed = 0;

      contacts.forEach(contact => {
        db.run(
          'INSERT OR IGNORE INTO contacts (phone_number, name, email) VALUES (?, ?, ?)',
          [contact.phone_number, contact.name, contact.email],
          function(err) {
            completed++;
            
            if (err) {
              console.error('Error inserting contact:', err);
              errors.push(`Failed to insert ${contact.phone_number}: ${err.message}`);
            } else if (this.changes > 0) {
              insertedCount++;
            } else {
              skippedCount++;
            }

            if (completed === contacts.length) {
              console.log(`CSV import completed: ${insertedCount} inserted, ${skippedCount} skipped`);
              
              res.json({
                success: true,
                message: `Successfully processed ${contacts.length} contacts`,
                inserted: insertedCount,
                skipped: skippedCount,
                total: contacts.length,
                errors: errors.length > 0 ? errors : undefined
              });
            }
          }
        );
      });
    })
    .on('error', (error) => {
      console.error('CSV parsing error:', error);
      if (fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
      res.status(500).json({ 
        error: 'Error processing CSV file', 
        details: error.message 
      });
    });
});

// Campaigns endpoints
app.get('/api/campaigns', (req, res) => {
  if (!db || !dbInitialized) {
    return res.json([]);
  }
  
  db.all(`
    SELECT c.*, 
           COUNT(cm.id) as total_messages,
           COUNT(CASE WHEN cm.status = 'sent' THEN 1 END) as sent_count,
           COUNT(CASE WHEN cm.status = 'failed' THEN 1 END) as failed_count,
           COUNT(CASE WHEN cm.status = 'pending' THEN 1 END) as pending_count
    FROM campaigns c
    LEFT JOIN campaign_messages cm ON c.id = cm.campaign_id
    GROUP BY c.id
    ORDER BY c.created_at DESC
  `, (err, rows) => {
    if (err) {
      console.error('Error fetching campaigns:', err);
      return res.status(500).json({ error: 'Failed to fetch campaigns' });
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
    return res.status(400).json({ error: 'Campaign name and message are required' });
  }

  if (message.length > 1000) {
    return res.status(400).json({ error: 'Message too long (max 1000 characters)' });
  }

  db.run(
    'INSERT INTO campaigns (name, message) VALUES (?, ?)',
    [name.trim(), message.trim()],
    function(err) {
      if (err) {
        console.error('Error creating campaign:', err);
        return res.status(500).json({ error: err.message });
      }
      
      console.log(`Campaign created: "${name}" (ID: ${this.lastID})`);
      
      res.json({ 
        id: this.lastID, 
        name: name.trim(), 
        message: message.trim(),
        status: 'draft',
        created_at: new Date().toISOString()
      });
    }
  );
});

// Enhanced campaign sending with real WhatsApp integration
app.post('/api/campaigns/:id/send', async (req, res) => {
  const campaignId = parseInt(req.params.id);

  if (!whatsappStatus.authenticated || !whatsappStatus.sessionId) {
    return res.status(400).json({ 
      error: 'WhatsApp not connected', 
      message: 'Please connect WhatsApp first using the Connect WhatsApp button'
    });
  }

  if (!db || !dbInitialized) {
    return res.status(503).json({ error: 'Database not ready' });
  }

  try {
    // Get campaign details
    const campaign = await new Promise((resolve, reject) => {
      db.get('SELECT * FROM campaigns WHERE id = ?', [campaignId], (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });

    if (!campaign) {
      return res.status(404).json({ error: 'Campaign not found' });
    }

    if (campaign.status === 'sending' || campaign.status === 'completed') {
      return res.status(400).json({ 
        error: 'Campaign already processed', 
        status: campaign.status 
      });
    }

    // Get all contacts
    const contacts = await new Promise((resolve, reject) => {
      db.all('SELECT * FROM contacts ORDER BY id', (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      });
    });

    if (contacts.length === 0) {
      return res.status(400).json({ error: 'No contacts available to send messages' });
    }

    // Verify WhatsApp session is still active
    try {
      const sessionStatus = await getWhatsAppSessionStatus(whatsappStatus.sessionId);
      if (!sessionStatus.ready) {
        return res.status(400).json({
          error: 'WhatsApp session not ready',
          sessionStatus: sessionStatus.status
        });
      }
    } catch (error) {
      return res.status(400).json({
        error: 'WhatsApp session verification failed',
        message: 'Please reconnect WhatsApp'
      });
    }

    console.log(`Starting real WhatsApp campaign "${campaign.name}" to ${contacts.length} contacts`);

    // Update campaign status
    db.run('UPDATE campaigns SET status = ?, total_contacts = ?, updated_at = ?', 
           ['sending', contacts.length, new Date().toISOString()]);

    // Initialize progress tracking
    campaignProgress = {
      isActive: true,
      percentage: 0,
      currentCampaign: campaign.name,
      totalContacts: contacts.length,
      sentCount: 0
    };

    // Send immediate response
    res.json({
      success: true,
      message: 'Campaign started successfully with real WhatsApp integration',
      campaignId: campaignId,
      totalContacts: contacts.length,
      status: 'sending'
    });

    // Process messages asynchronously with real WhatsApp sending
    let sentCount = 0;
    let failedCount = 0;

    for (let i = 0; i < contacts.length; i++) {
      const contact = contacts[i];
      
      try {
        // Add delay between messages to avoid rate limiting
        if (i > 0) {
          await new Promise(resolve => setTimeout(resolve, 5000));
        }

        // Send real WhatsApp message
        await sendWhatsAppMessage(
          whatsappStatus.sessionId, 
          contact.phone_number, 
          campaign.message
        );
        
        // Record successful message
        await new Promise((resolve) => {
          db.run(`
            INSERT INTO campaign_messages 
            (campaign_id, contact_id, phone_number, message, status, sent_at) 
            VALUES (?, ?, ?, ?, ?, ?)
          `, [
            campaignId, 
            contact.id, 
            contact.phone_number, 
            campaign.message, 
            'sent',
            new Date().toISOString()
          ], resolve);
        });

        sentCount++;
        console.log(`WhatsApp message sent to ${contact.phone_number} (${contact.name})`);
        
      } catch (error) {
        console.error(`Error sending WhatsApp message to ${contact.phone_number}:`, error);
        failedCount++;
        
        // Record failed message
        await new Promise((resolve) => {
          db.run(`
            INSERT INTO campaign_messages 
            (campaign_id, contact_id, phone_number, message, status, error_message) 
            VALUES (?, ?, ?, ?, ?, ?)
          `, [
            campaignId, 
            contact.id, 
            contact.phone_number, 
            campaign.message, 
            'failed', 
            error.message || 'Failed to send WhatsApp message'
          ], resolve);
        });
      }
      
      // Update progress
      const percentage = Math.round(((i + 1) / contacts.length) * 100);
      campaignProgress = {
        isActive: true,
        percentage,
        currentCampaign: campaign.name,
        totalContacts: contacts.length,
        sentCount
      };
      
      console.log(`Campaign progress: ${percentage}% (${sentCount} sent, ${failedCount} failed)`);
    }

    // Update final campaign status
    const finalStatus = failedCount === 0 ? 'completed' : 'completed_with_errors';
    db.run(
      'UPDATE campaigns SET status = ?, sent_count = ?, failed_count = ?, updated_at = ?',
      [finalStatus, sentCount, failedCount, new Date().toISOString()]
    );

    campaignProgress.isActive = false;
    campaignProgress.percentage = 100;

    console.log(`WhatsApp campaign "${campaign.name}" completed: ${sentCount} sent, ${failedCount} failed`);

    // Reset progress after 10 seconds
    setTimeout(() => {
      campaignProgress = {
        isActive: false,
        percentage: 0,
        currentCampaign: null,
        totalContacts: 0,
        sentCount: 0
      };
    }, 10000);

  } catch (error) {
    console.error('Campaign execution error:', error);
    campaignProgress.isActive = false;
    
    // Update campaign as failed
    db.run('UPDATE campaigns SET status = ?, updated_at = ?', 
           ['failed', new Date().toISOString()]);
  }
});

// WhatsApp integration endpoints using the auth server
app.post('/api/whatsapp/connect', async (req, res) => {
  try {
    console.log('Creating new WhatsApp session...');
    const sessionData = await createWhatsAppSession();
    
    whatsappStatus.sessionId = sessionData.sessionId;
    whatsappStatus.connected = false;
    whatsappStatus.authenticated = false;
    
    res.json({
      success: true,
      sessionId: sessionData.sessionId,
      message: 'WhatsApp session created. Please check QR code.',
      instructions: sessionData.instructions
    });
  } catch (error) {
    console.error('Failed to connect WhatsApp:', error);
    res.status(500).json({
      error: 'Failed to create WhatsApp session',
      message: error.message
    });
  }
});

app.get('/api/whatsapp/status', async (req, res) => {
  if (!whatsappStatus.sessionId) {
    return res.json({
      authenticated: false,
      connected: false,
      qrCode: null,
      message: 'No active session. Please connect WhatsApp first.'
    });
  }

  try {
    const sessionStatus = await getWhatsAppSessionStatus(whatsappStatus.sessionId);
    
    // Update local status based on session
    whatsappStatus.authenticated = sessionStatus.authenticated;
    whatsappStatus.connected = sessionStatus.ready;
    whatsappStatus.qrCode = sessionStatus.qrCodeUrl;
    whatsappStatus.phoneNumber = sessionStatus.phoneNumber;
    whatsappStatus.userName = sessionStatus.userName;

    res.json({
      authenticated: sessionStatus.authenticated,
      ready: sessionStatus.ready,
      connected: sessionStatus.ready,
      qrCode: sessionStatus.qrCodeUrl,
      qrCodeFile: sessionStatus.qrCodeFile,
      phoneNumber: sessionStatus.phoneNumber,
      userName: sessionStatus.userName,
      status: sessionStatus.status,
      sessionId: sessionStatus.sessionId,
      expired: sessionStatus.expired
    });
  } catch (error) {
    console.error('Failed to get WhatsApp status:', error);
    res.status(500).json({
      error: 'Failed to get WhatsApp session status',
      message: error.message
    });
  }
});

app.post('/api/whatsapp/disconnect', (req, res) => {
  // Reset local WhatsApp status
  whatsappStatus = {
    connected: false,
    sessionId: null,
    qrCode: null,
    authenticated: false,
    phoneNumber: null,
    userName: null
  };
  
  console.log('WhatsApp session disconnected locally');
  
  res.json({ 
    success: true, 
    message: 'WhatsApp disconnected successfully' 
  });
});

// Legacy endpoints for compatibility
app.get('/api/whatsapp/qr', (req, res) => {
  res.redirect('/api/whatsapp/status');
});

app.post('/api/whatsapp/authenticate', (req, res) => {
  res.redirect(307, '/api/whatsapp/connect');
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Server error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
  });
});

// Start server
const startServer = async () => {
  try {
    console.log('Starting AJ Sender Backend with WhatsApp Integration...');
    
    await initializeDatabase();
    console.log('Database ready');
    
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`AJ Sender Backend running on port ${PORT}`);
      console.log(`WhatsApp Auth Server URL: ${WHATSAPP_AUTH_URL}`);
      console.log(`Health check: http://localhost:${PORT}/health`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down gracefully...');
  if (db) {
    db.close();
  }
  process.exit(0);
});

startServer();
WHATSAPP_INTEGRATED_BACKEND

# --- backend/package.json -----------------------------------------------------
cat > backend/package.json <<'EOF'
{
  "name": "ajsender-backend",
  "version": "2.0.0",
  "description": "AJ Sender WhatsApp bulk messaging backend with real WhatsApp integration",
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
    "sqlite3": "^5.1.6",
    "axios": "^1.5.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "author": "AJ Ricardo",
  "license": "MIT"
}
EOF

# --- Minimal backend Dockerfile (safe to overwrite) ---------------------------
cat > backend/Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 3001
CMD ["node","server.js"]
EOF

# --- WhatsApp server scaffold -------------------------------------------------
mkdir -p whatsapp-server

# If you already have whatsapp-auth.js and setup.js at repo root, copy them...
if [ -f whatsapp-auth.js ]; then
  cp -f whatsapp-auth.js whatsapp-server/server.js
else
  # Fallback stub so build doesn’t fail if auth file isn’t present
  cat > whatsapp-server/server.js <<'EOF'
const express = require('express');
const app = express();
app.use(express.json());
app.get('/health', (_req,res)=>res.json({status:'stub', ready:false}));
app.post('/api/session/create', (_req,res)=>res.json({sessionId:'stub-session', instructions:'Provide real whatsapp-auth.js'}));
app.get('/api/session/:id/status', (req,res)=>res.json({sessionId:req.params.id, authenticated:false, ready:false, status:'stub'}));
app.post('/api/session/:id/send', (_req,res)=>res.status(501).json({error:'Not implemented in stub'}));
app.listen(process.env.PORT||3002, ()=>console.log('Stub WhatsApp server on',process.env.PORT||3002));
EOF
fi

if [ -f setup.js ]; then
  cp -f setup.js whatsapp-server/
fi

# --- whatsapp-server/package.json --------------------------------------------
cat > whatsapp-server/package.json <<'EOF'
{
  "name": "ajsender-whatsapp-server",
  "version": "3.0.0",
  "description": "Real WhatsApp Web.js integration server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "setup": "node setup.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "whatsapp-web.js": "^1.23.0",
    "qrcode": "^1.5.3",
    "fs-extra": "^11.1.1",
    "uuid": "^9.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "author": "AJ Ricardo",
  "license": "MIT"
}
EOF

# --- whatsapp-server/Dockerfile ----------------------------------------------
cat > whatsapp-server/Dockerfile <<'EOF'
FROM node:18-alpine

# deps for Chromium driven by whatsapp-web.js/puppeteer
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .

RUN mkdir -p sessions public/qr .wwebjs_auth .wwebjs_cache
RUN addgroup -g 1001 -S nodejs && adduser -S whatsapp -u 1001
RUN chown -R whatsapp:nodejs /app
USER whatsapp

EXPOSE 3002
CMD ["node","server.js"]
EOF

# --- Frontend Dashboard patch -------------------------------------------------
mkdir -p frontend/src/components
cat > frontend/src/components/Dashboard.tsx <<'WHATSAPP_FRONTEND'
import React, { useState, useEffect, useRef } from 'react'
import { Users, MessageSquare, Send, BarChart3, Plus, TrendingUp, Upload, CheckCircle, XCircle, Heart, Moon, Sun, Wifi, X, QrCode, RefreshCw } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface Metrics {
  totalContacts: number
  totalCampaigns: number
  totalMessages: number
  sentMessages: number
}

interface SystemStatus {
  backend: string
  whatsapp: string
  authenticated: boolean
  sessionId?: string
  phoneNumber?: string
  userName?: string
}

interface Contact {
  id: number
  phone_number: string
  name: string
  email?: string
  created_at: string
}

interface Campaign {
  id: number
  name: string
  message: string
  status: string
  sent_count: number
  failed_count: number
  total_messages: number
  created_at: string
}

interface CampaignProgress {
  isActive: boolean
  percentage: number
  currentCampaign: string | null
  totalContacts: number
  sentCount: number
}

interface WhatsAppStatus {
  authenticated: boolean
  ready: boolean
  connected: boolean
  qrCode?: string
  phoneNumber?: string
  userName?: string
  status: string
  expired?: boolean
}

const Dashboard: React.FC = () => {
  const [isDark, setIsDark] = useState(false)
  const [showUploadModal, setShowUploadModal] = useState(false)
  const [showCampaignModal, setShowCampaignModal] = useState(false)
  const [showAnalyticsModal, setShowAnalyticsModal] = useState(false)
  const [showWhatsAppModal, setShowWhatsAppModal] = useState(false)
  const [contacts, setContacts] = useState<Contact[]>([])
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [metrics, setMetrics] = useState<Metrics>({
    totalContacts: 0,
    totalCampaigns: 0,
    totalMessages: 0,
    sentMessages: 0
  })
  const [systemStatus, setSystemStatus] = useState<SystemStatus>({
    backend: 'unknown',
    whatsapp: 'disconnected',
    authenticated: false
  })
  const [campaignProgress, setCampaignProgress] = useState<CampaignProgress>({
    isActive: false,
    percentage: 0,
    currentCampaign: null,
    totalContacts: 0,
    sentCount: 0
  })
  const [whatsappStatus, setWhatsAppStatus] = useState<WhatsAppStatus>({
    authenticated: false,
    ready: false,
    connected: false,
    status: 'disconnected'
  })

  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [metricsRes, statusRes, contactsRes, campaignsRes, progressRes] = await Promise.all([
          fetch('/api/metrics'),
          fetch('/api/status'),
          fetch('/api/contacts'),
          fetch('/api/campaigns'),
          fetch('/api/campaigns/progress')
        ])

        if (metricsRes.ok) {
          const metricsData = await metricsRes.json()
          setMetrics(metricsData)
        }

        if (statusRes.ok) {
          const statusData = await statusRes.json()
          setSystemStatus(statusData)
        }

        if (contactsRes.ok) {
          const contactsData = await contactsRes.json()
          setContacts(contactsData)
        }

        if (campaignsRes.ok) {
          const campaignsData = await campaignsRes.json()
          setCampaigns(campaignsData)
        }

        if (progressRes.ok) {
          const progressData = await progressRes.json()
          setCampaignProgress(progressData)
        }
      } catch (error) {
        console.error('Error fetching data:', error)
      }
    }

    fetchData()
    const interval = setInterval(fetchData, 5000)
    return () => clearInterval(interval)
  }, [])

  const connectWhatsApp = async () => {
    try {
      const response = await fetch('/api/whatsapp/connect', {
        method: 'POST'
      })
      const result = await response.json()
      
      if (response.ok) {
        setShowWhatsAppModal(true)
        pollWhatsAppStatus()
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error connecting to WhatsApp: ' + error)
    }
  }

  const pollWhatsAppStatus = async () => {
    try {
      const response = await fetch('/api/whatsapp/status')
      const status = await response.json()
      
      if (response.ok) {
        setWhatsAppStatus(status)
        if (!status.authenticated && !status.expired) {
          setTimeout(pollWhatsAppStatus, 2000)
        }
      }
    } catch (error) {
      console.error('Error polling WhatsApp status:', error)
    }
  }

  const disconnectWhatsApp = async () => {
    try {
      const response = await fetch('/api/whatsapp/disconnect', {
        method: 'POST'
      })
      
      if (response.ok) {
        setWhatsAppStatus({
          authenticated: false,
          ready: false,
          connected: false,
          status: 'disconnected'
        })
        setShowWhatsAppModal(false)
      }
    } catch (error) {
      console.error('Error disconnecting WhatsApp:', error)
    }
  }

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    const formData = new FormData()
    formData.append('csvFile', file)

    try {
      const response = await fetch('/api/contacts/upload', {
        method: 'POST',
        body: formData
      })

      const result = await response.json()
      
      if (response.ok) {
        alert(`Success! Imported ${result.inserted} contacts, skipped ${result.skipped} duplicates.`)
        const contactsRes = await fetch('/api/contacts')
        if (contactsRes.ok) {
          const contactsData = await contactsRes.json()
          setContacts(contactsData)
        }
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error uploading file: ' + error)
    }

    setShowUploadModal(false)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const handleCreateCampaign = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const formData = new FormData(event.currentTarget)
    const name = formData.get('name') as string
    const message = formData.get('message') as string

    if (!name || !message) {
      alert('Please fill in both campaign name and message.')
      return
    }

    try {
      const response = await fetch('/api/campaigns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, message })
      })

      const result = await response.json()
      
      if (response.ok) {
        alert('Campaign created successfully!')
        const campaignsRes = await fetch('/api/campaigns')
        if (campaignsRes.ok) {
          const campaignsData = await campaignsRes.json()
          setCampaigns(campaignsData)
        }
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error creating campaign: ' + error)
    }

    setShowCampaignModal(false)
  }

  const handleSendCampaign = async (campaignId: number) => {
    if (!systemStatus.authenticated) {
      alert('Please connect WhatsApp first before sending campaigns.')
      setShowWhatsAppModal(true)
      return
    }

    if (!confirm('Are you sure you want to send this campaign to all contacts via WhatsApp?')) return

    try {
      const response = await fetch(`/api/campaigns/${campaignId}/send`, {
        method: 'POST'
      })

      const result = await response.json()
      
      if (response.ok) {
        alert('Campaign started! Messages are being sent via WhatsApp. Check the progress bar.')
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error sending campaign: ' + error)
    }
  }

  const Modal = ({ show, onClose, title, children, size = 'md' }: { 
    show: boolean
    onClose: () => void
    title: string
    children: React.ReactNode
    size?: 'sm' | 'md' | 'lg' | 'xl'
  }) => {
    const sizeClasses = {
      sm: 'max-w-sm',
      md: 'max-w-md',
      lg: 'max-w-lg',
      xl: 'max-w-2xl'
    }

    return (
      <AnimatePresence>
        {show && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
            onClick={onClose}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              onClick={e => e.stopPropagation()}
              className={`${sizeClasses[size]} w-full rounded-2xl shadow-xl ${
                isDark ? 'bg-gray-800 border border-gray-700' : 'bg-white border border-gray-200'
              }`}
            >
              <div className={`flex items-center justify-between p-6 border-b ${
                isDark ? 'border-gray-700' : 'border-gray-200'
              }`}>
                <h3 className={`text-lg font-semibold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {title}
                </h3>
                <button
                  onClick={onClose}
                  className={`p-2 rounded-lg hover:bg-gray-100 ${isDark ? 'hover:bg-gray-700' : ''}`}
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              <div className="p-6">
                {children}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    )
  }

  return (
    <div className={`min-h-screen transition-all duration-500 ${
      isDark ? 'bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900' : 'bg-gradient-to-br from-gray-50 via-white to-gray-100'
    }`}>
      {/* Campaign Progress Bar */}
      <AnimatePresence>
        {campaignProgress.isActive && (
          <motion.div 
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="fixed top-0 left-0 right-0 z-50"
          >
            <div className={`h-2 ${isDark ? 'bg-gray-800' : 'bg-gray-100'}`}>
              <motion.div
                className="h-full bg-gradient-to-r from-green-500 via-emerald-500 to-green-600 relative overflow-hidden shadow-lg"
                initial={{ width: 0 }}
                animate={{ width: `${campaignProgress.percentage}%` }}
                transition={{ duration: 0.8, ease: [0.4, 0, 0.2, 1] }}
              >
                <motion.div
                  className="absolute inset-0 bg-gradient-to-r from-transparent via-white/40 to-transparent"
                  animate={{ x: [-200, 400] }}
                  transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                />
              </motion.div>
            </div>
            
            {campaignProgress.percentage > 0 && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                className={`absolute top-3 right-4 px-3 py:1 px-3 py-1 rounded-full text-xs font-bold shadow-lg ${
                  isDark 
                    ? 'bg-gray-800 text-green-400 border border-green-500/30' 
                    : 'bg-white text-green-600 border border-green-200'
                }`}
              >
                {campaignProgress.currentCampaign}: {campaignProgress.percentage}% ({campaignProgress.sentCount}/{campaignProgress.totalContacts})
              </motion.div>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      <motion.header 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className={`sticky top-0 z-40 backdrop-blur-xl border-b transition-all duration-300 ${
          isDark ? 'bg-gray-900/80 border-gray-700/50' : 'bg-white/80 border-gray-200/50'
        }`}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl bg-gradient-to-r from-green-500 to-emerald-600 shadow-lg">
                <Send className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className={`text-xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  AJ Sender
                </h1>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  WhatsApp Bulk Messaging
                </p>
              </div>
            </div>
            
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-3">
                <span className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium ${
                  systemStatus.backend === 'running' 
                    ? 'bg-green-100 text-green-700 border border-green-200'
                    : 'bg-red-100 text-red-700 border border-red-200'
                }`}>
                  {systemStatus.backend === 'running' ? <CheckCircle className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                  Backend
                </span>
                <button
                  onClick={() => systemStatus.authenticated ? disconnectWhatsApp() : connectWhatsApp()}
                  className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium cursor-pointer transition-colors ${
                    systemStatus.authenticated 
                      ? 'bg-green-100 text-green-700 border border-green-200 hover:bg-green-200'
                      : 'bg-red-100 text-red-700 border border-red-200 hover:bg-red-200'
                  }`}
                >
                  {systemStatus.authenticated ? <Wifi className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                  WhatsApp {systemStatus.authenticated ? '(Connected)' : '(Click to Connect)'}
                </button>
              </div>

              <button
                onClick={() => setIsDark(!isDark)}
                className={`p-2 rounded-lg transition-all duration-300 ${
                  isDark ? 'bg-gray-700 hover:bg-gray-600 text-yellow-400' : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
                }`}
              >
                {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
              </button>
            </div>
          </div>
        </div>
      </motion.header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Total Contacts
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalContacts.toLocaleString()}
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Users className="w-8 h-8 text-blue-500" />
              </div>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Campaigns
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalCampaigns.toLocaleString()}
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <MessageSquare className="w-8 h-8 text-green-500" />
              </div>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Messages
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalMessages.toLocaleString()}
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Send className="w-8 h-8 text-purple-500" />
              </div>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Success Rate
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalMessages > 0 ? Math.round((metrics.sentMessages / metrics.totalMessages) * 100) : 0}%
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <TrendingUp className="w-8 h-8 text-orange-500" />
              </div>
            </div>
          </motion.div>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8"
        >
          <motion.div
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setShowUploadModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Upload className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div className="flex-1">
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  Upload Contacts
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Import contacts from CSV
                </p>
              </div>
            </div>
          </motion.div>

          <motion.div
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setShowCampaignModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Plus className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div className="flex-1">
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  Create Campaign
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Start a new message campaign
                </p>
              </div>
            </div>
          </motion.div>

          <motion.div
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setShowAnalyticsModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <BarChart3 className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div className="flex-1">
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  View Analytics
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Track campaign performance
                </p>
              </div>
            </div>
          </motion.div>
        </motion.div>

        <footer className={`text-center py-8 border-t ${isDark ? 'border-gray-700' : 'border-gray-200'}`}>
          <div className="flex items-center justify-center gap-2 mb-2">
            <span className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
              Made with
            </span>
            <Heart className="w-4 h-4 text-red-500" />
            <span className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
              for my girl
            </span>
          </div>
          <p className={`text-xs ${isDark ? 'text-gray-500' : 'text-gray-500'}`}>
            AJ Sender v2.0 - Real WhatsApp Integration
          </p>
        </footer>
      </main>

      {/* Upload Modal */}
      <Modal show={showUploadModal} onClose={() => setShowUploadModal(false)} title="Upload Contacts">
        <div className="space-y-4">
          <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
            Upload a CSV file with contacts. Supported columns: phone_number, phone, number, name, email
          </p>
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv"
            onChange={handleFileUpload}
            className={`w-full p-3 border rounded-lg ${
              isDark ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300'
            }`}
          />
          <div className={`text-xs ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
            Current contacts: {contacts.length}
          </div>
        </div>
      </Modal>

      {/* Campaign Modal */}
      <Modal show={showCampaignModal} onClose={() => setShowCampaignModal(false)} title="Create Campaign">
        <form onSubmit={handleCreateCampaign} className="space-y-4">
          <div>
            <label className={`block text-sm font-medium mb-2 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>
              Campaign Name
            </label>
            <input
              name="name"
              type="text"
              required
              className={`w-full p-3 border rounded-lg ${
                isDark ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300'
              }`}
              placeholder="Enter campaign name"
            />
          </div>
          <div>
            <label className={`block text-sm font-medium mb-2 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>
              WhatsApp Message
            </label>
            <textarea
              name="message"
              required
              rows={4}
              maxLength={1000}
              className={`w-full p-3 border rounded-lg ${
                isDark ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300'
              }`}
              placeholder="Enter your WhatsApp message (max 1000 characters)"
            />
            <div className={`text-xs mt-1 ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
              This message will be sent to all contacts via WhatsApp
            </div>
          </div>
          <button
            type="submit"
            className="w-full bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg font-medium"
          >
            Create Campaign
          </button>
        </form>
      </Modal>

      {/* Analytics Modal */}
      <Modal show={showAnalyticsModal} onClose={() => setShowAnalyticsModal(false)} title="Analytics & Campaigns" size="xl">
        <div className="space-y-6 max-h-96 overflow-y-auto">
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
              <div className="text-2xl font-bold text-green-500">{contacts.length}</div>
              <div className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>Total Contacts</div>
            </div>
            <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
              <div className="text-2xl font-bold text-blue-500">{campaigns.length}</div>
              <div className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>Campaigns</div>
            </div>
          </div>
          
          <div>
            <h4 className={`font-semibold mb-4 ${isDark ? 'text-white' : 'text-gray-900'}`}>
              Recent Campaigns
            </h4>
            <div className="space-y-3">
              {campaigns.length === 0 ? (
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
                  No campaigns created yet
                </p>
              ) : (
                campaigns.slice(0, 5).map(campaign => (
                  <div
                    key={campaign.id}
                    className={`p-4 rounded-lg border ${isDark ? 'bg-gray-700 border-gray-600' : 'bg-gray-50 border-gray-200'}`}
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-2">
                          <h5 className={`font-medium ${isDark ? 'text-white' : 'text-gray-900'}`}>
                            {campaign.name}
                          </h5>
                          <span className={`inline-block px-2 py-1 text-xs rounded-full ${
                            campaign.status === 'completed' ? 'bg-green-100 text-green-800' :
                            campaign.status === 'sending' ? 'bg-yellow-100 text-yellow-800' :
                            campaign.status === 'completed_with_errors' ? 'bg-orange-100 text-orange-800' :
                            campaign.status === 'failed' ? 'bg-red-100 text-red-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            {campaign.status}
                          </span>
                        </div>
                        <p className={`text-sm mt-1 ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                          {campaign.message.length > 100 ? campaign.message.substring(0, 100) + '...' : campaign.message}
                        </p>
                        {campaign.total_messages > 0 && (
                          <div className="flex gap-4 mt-2 text-xs">
                            <span className="text-green-600">✓ {campaign.sent_count} sent</span>
                            {campaign.failed_count > 0 && (
                              <span className="text-red-600">✗ {campaign.failed_count} failed</span>
                            )}
                          </div>
                        )}
                      </div>
                      {campaign.status === 'draft' && (
                        <button
                          onClick={() => handleSendCampaign(campaign.id)}
                          className="ml-4 px-4 py-2 bg-green-500 hover:bg-green-600 text-white text-sm rounded-lg flex items-center gap-2"
                        >
                          <Send className="w-4 h-4" />
                          Send via WhatsApp
                        </button>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </Modal>

      {/* WhatsApp Connection Modal */}
      <Modal show={showWhatsAppModal} onClose={() => setShowWhatsAppModal(false)} title="WhatsApp Connection" size="lg">
        <div className="space-y-6">
          {whatsappStatus.authenticated ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle className="w-8 h-8 text-green-600" />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                WhatsApp Connected!
              </h3>
              {whatsappStatus.userName && (
                <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                  Connected as: {whatsappStatus.userName} ({whatsappStatus.phoneNumber})
                </p>
              )}
              <button
                onClick={disconnectWhatsApp}
                className="mt-4 px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg"
              >
                Disconnect WhatsApp
              </button>
            </div>
          ) : whatsappStatus.qrCode ? (
            <div className="text-center">
              <div className="w-64 h-64 mx-auto mb-4 bg-white p-4 rounded-lg">
                <img 
                  src={whatsappStatus.qrCode} 
                  alt="WhatsApp QR Code" 
                  className="w-full h-full"
                />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                Scan QR Code
              </h3>
              <div className={`text-sm space-y-2 ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                <p>1. Open WhatsApp on your phone</p>
                <p>2. Go to Settings → Linked Devices</p>
                <p>3. Tap "Link a Device"</p>
                <p>4. Scan this QR code</p>
              </div>
              <button
                onClick={pollWhatsAppStatus}
                className="mt-4 px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg flex items-center gap-2 mx-auto"
              >
                <RefreshCw className="w-4 h-4" />
                Refresh Status
              </button>
            </div>
          ) : whatsappStatus.expired ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <XCircle className="w-8 h-8 text-red-600" />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                Session Expired
              </h3>
              <p className={`text-sm mb-4 ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                The QR code has expired. Please create a new session.
              </p>
              <button
                onClick={connectWhatsApp}
                className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg"
              >
                Create New Session
              </button>
            </div>
          ) : (
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <QrCode className="w-8 h-8 text-blue-600" />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                Generating QR Code...
              </h3>
              <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                Please wait while we create your WhatsApp session
              </p>
            </div>
          )}
        </div>
      </Modal>
    </div>
  )
}

export default Dashboard
WHATSAPP_FRONTEND

# --- docker-compose.yml (fixed YAML and quotes) -------------------------------
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:80"
    environment:
      - NODE_ENV=production
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
      - DATABASE_URL=sqlite:///app/data/database.sqlite
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

# --- required directories -----------------------------------------------------
mkdir -p whatsapp-sessions whatsapp-cache whatsapp-public data logs

# --- build & run --------------------------------------------------------------
docker-compose down || true
docker-compose build --no-cache
docker-compose up -d

# --- basic health checks ------------------------------------------------------
sleep 20

echo "=== Service Status ==="
docker-compose ps

echo "=== Backend Health ==="
curl -s http://localhost:3001/health | { jq . 2>/dev/null || cat; }

echo "=== WhatsApp Server Health ==="
curl -s http://localhost:3002/health | { jq . 2>/dev/null || cat; }

echo
echo "🎉 AJ Sender is now live with real WhatsApp integration!"
echo "📱 Frontend: http://localhost:3000"
echo "🔧 Backend:  http://localhost:3001"
echo "📞 WhatsApp: http://localhost:3002"
echo
echo "✅ Features:"
echo "  Real WhatsApp Web.js integration … QR auth … CSV contacts … progress tracking"
echo
echo "💝 AJ Sender v2.0"