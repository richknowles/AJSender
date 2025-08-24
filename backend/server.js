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
