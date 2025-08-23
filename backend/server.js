const express = require('express');
const cors = require('cors');
const multer = require('multer');
const csv = require('csv-parser');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const QRCode = require('qrcode');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({
  origin: ['http://localhost:3000', 'https://sender.ajricardo.com'],
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static assets
app.use('/assets', express.static(path.join(__dirname, '../frontend/public/assets')));

// File upload configuration
const upload = multer({ dest: '/tmp/uploads/' });

// Database and state
let db = null;
let dbInitialized = false;
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
  qrCode: null,
  sessionId: null
};

// Initialize SQLite database
function initializeDatabase() {
  try {
    const dataDir = path.join(__dirname, 'data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    
    const dbPath = path.join(dataDir, 'ajsender.sqlite');
    console.log('Initializing database at:', dbPath);
    
    db = new sqlite3.Database(dbPath, (err) => {
      if (err) {
        console.error('Database connection error:', err);
        return;
      }
      console.log('✅ Connected to SQLite database');
      
      // Create tables
      db.serialize(() => {
        db.run(`CREATE TABLE IF NOT EXISTS contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone_number TEXT UNIQUE NOT NULL,
          name TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);

        db.run(`CREATE TABLE IF NOT EXISTS campaigns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          message TEXT NOT NULL,
          status TEXT DEFAULT 'draft',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);

        db.run(`CREATE TABLE IF NOT EXISTS campaign_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          campaign_id INTEGER,
          contact_id INTEGER,
          phone_number TEXT NOT NULL,
          message TEXT NOT NULL,
          status TEXT DEFAULT 'pending',
          sent_at DATETIME,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);

        dbInitialized = true;
        console.log('✅ Database tables initialized');
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
    whatsapp: whatsappStatus.connected ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

// System status endpoint
app.get('/api/status', (req, res) => {
  res.json({
    backend: 'running',
    whatsapp: whatsappStatus.connected ? 'authenticated' : 'disconnected',
    authenticated: whatsappStatus.connected,
    database: dbInitialized ? 'connected' : 'connecting'
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
  
  db.all('SELECT * FROM contacts ORDER BY created_at DESC LIMIT 100', (err, rows) => {
    if (err) {
      console.error('Error fetching contacts:', err);
      return res.json([]);
    }
    res.json(rows || []);
  });
});

app.post('/api/contacts', (req, res) => {
  if (!db || !dbInitialized) {
    return res.status(503).json({ error: 'Database not ready' });
  }
  
  const { phone_number, name } = req.body;
  
  if (!phone_number) {
    return res.status(400).json({ error: 'Phone number is required' });
  }

  db.run(
    'INSERT OR REPLACE INTO contacts (phone_number, name) VALUES (?, ?)',
    [phone_number, name || ''],
    function(err) {
      if (err) {
        console.error('Error inserting contact:', err);
        return res.status(500).json({ error: err.message });
      }
      res.json({ 
        id: this.lastID, 
        phone_number, 
        name,
        message: 'Contact saved successfully' 
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
  const errors = [];
  let processedCount = 0;

  fs.createReadStream(req.file.path)
    .pipe(csv())
    .on('data', (row) => {
      processedCount++;
      
      const phoneNumber = row.phone_number || row.phone || row.number || row.Phone || row.Number;
      const name = row.name || row.Name || row.first_name || row.FirstName || '';

      if (phoneNumber) {
        const cleanPhone = phoneNumber.toString().replace(/[^\d+]/g, '');
        if (cleanPhone) {
          contacts.push({ phone_number: cleanPhone, name: name.toString() });
        } else {
          errors.push(`Row ${processedCount}: Invalid phone number format`);
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
          errors 
        });
      }

      if (!db || !dbInitialized) {
        return res.status(503).json({ error: 'Database not ready' });
      }

      let insertedCount = 0;
      let skippedCount = 0;

      const insertPromises = contacts.map(contact => {
        return new Promise((resolve) => {
          db.run(
            'INSERT OR IGNORE INTO contacts (phone_number, name) VALUES (?, ?)',
            [contact.phone_number, contact.name],
            function(err) {
              if (err) {
                console.error('Error inserting contact:', err);
                resolve({ success: false });
              } else if (this.changes > 0) {
                insertedCount++;
                resolve({ success: true, inserted: true });
              } else {
                skippedCount++;
                resolve({ success: true, inserted: false });
              }
            }
          );
        });
      });

      Promise.all(insertPromises).then(() => {
        res.json({
          success: true,
          message: `Processed ${contacts.length} contacts`,
          inserted: insertedCount,
          skipped: skippedCount,
          errors: errors.length > 0 ? errors : undefined
        });
      });
    })
    .on('error', (error) => {
      if (fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
      res.status(500).json({ error: 'Error processing CSV file: ' + error.message });
    });
});

// Campaign endpoints
app.get('/api/campaigns', (req, res) => {
  if (!db || !dbInitialized) {
    return res.json([]);
  }
  
  db.all(`
    SELECT c.*, 
           COUNT(cm.id) as total_messages,
           COUNT(CASE WHEN cm.status = 'sent' THEN 1 END) as sent_count,
           COUNT(CASE WHEN cm.status = 'delivered' THEN 1 END) as delivered_count
    FROM campaigns c
    LEFT JOIN campaign_messages cm ON c.id = cm.campaign_id
    GROUP BY c.id
    ORDER BY c.created_at DESC
  `, (err, rows) => {
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

// Send campaign endpoint with progress tracking
app.post('/api/campaigns/:id/send', async (req, res) => {
  const campaignId = req.params.id;

  if (!whatsappStatus.connected) {
    return res.status(400).json({ error: 'WhatsApp not connected' });
  }

  if (!db || !dbInitialized) {
    return res.status(503).json({ error: 'Database not ready' });
  }

  try {
    // Get campaign and contacts
    const campaign = await new Promise((resolve, reject) => {
      db.get('SELECT * FROM campaigns WHERE id = ?', [campaignId], (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });

    if (!campaign) {
      return res.status(404).json({ error: 'Campaign not found' });
    }

    const contacts = await new Promise((resolve, reject) => {
      db.all('SELECT * FROM contacts', (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });

    if (contacts.length === 0) {
      return res.status(400).json({ error: 'No contacts available' });
    }

    // Initialize progress
    campaignProgress = {
      isActive: true,
      percentage: 0,
      currentCampaign: campaign.name,
      totalContacts: contacts.length,
      sentCount: 0
    };

    // Update campaign status
    db.run('UPDATE campaigns SET status = ? WHERE id = ?', ['sending', campaignId]);

    console.log(`Starting campaign "${campaign.name}" to ${contacts.length} contacts...`);
    
    // Simulate sending with progress updates
    let sentCount = 0;
    
    for (let i = 0; i < contacts.length; i++) {
      const contact = contacts[i];
      
      // Simulate delay
      await new Promise(resolve => setTimeout(resolve, 300));
      
      // Record message
      db.run(`
        INSERT INTO campaign_messages 
        (campaign_id, contact_id, phone_number, message, status, sent_at) 
        VALUES (?, ?, ?, ?, ?, ?)
      `, [campaignId, contact.id, contact.phone_number, campaign.message, 'sent', new Date().toISOString()]);

      sentCount++;
      
      // Update progress
      campaignProgress.sentCount = sentCount;
      campaignProgress.percentage = Math.round((sentCount / contacts.length) * 100);
      
      console.log(`Progress: ${campaignProgress.percentage}% (${sentCount}/${contacts.length})`);
    }

    // Complete campaign
    campaignProgress.isActive = false;
    campaignProgress.percentage = 100;
    db.run('UPDATE campaigns SET status = ? WHERE id = ?', ['completed', campaignId]);

    console.log(`Campaign completed! ${sentCount} messages sent.`);

    // Reset progress after 5 seconds
    setTimeout(() => {
      campaignProgress = {
        isActive: false,
        percentage: 0,
        currentCampaign: null,
        totalContacts: 0,
        sentCount: 0
      };
    }, 5000);

    res.json({
      success: true,
      sent: sentCount,
      total: contacts.length,
      message: `Campaign sent successfully! ${sentCount} messages delivered.`
    });

  } catch (error) {
    console.error('Campaign send error:', error);
    campaignProgress.isActive = false;
    db.run('UPDATE campaigns SET status = ? WHERE id = ?', ['failed', campaignId]);
    res.status(500).json({ error: error.message });
  }
});

// WhatsApp endpoints
app.get('/api/whatsapp/qr', (req, res) => {
  if (whatsappStatus.connected) {
    return res.json({ authenticated: true, qrCode: null });
  }
  
  // Generate a sample QR for demo
  if (!whatsappStatus.qrCode) {
    const sampleData = `https://wa.me/qr/demo-${Date.now()}`;
    QRCode.toDataURL(sampleData)
      .then(qrDataUrl => {
        whatsappStatus.qrCode = qrDataUrl;
        res.json({
          authenticated: false,
          qrCode: qrDataUrl,
          status: 'qr_ready',
          message: 'Scan QR code to connect'
        });
      })
      .catch(err => {
        res.json({
          authenticated: false,
          qrCode: null,
          status: 'error',
          message: 'Failed to generate QR code'
        });
      });
  } else {
    res.json({
      authenticated: false,
      qrCode: whatsappStatus.qrCode,
      status: 'qr_ready',
      message: 'Scan QR code to connect'
    });
  }
});

app.post('/api/whatsapp/authenticate', (req, res) => {
  // Simulate authentication
  whatsappStatus.connected = true;
  whatsappStatus.qrCode = null;
  console.log('WhatsApp authenticated (simulated)');
  res.json({ success: true, message: 'WhatsApp connected successfully' });
});

app.post('/api/whatsapp/logout', (req, res) => {
  whatsappStatus.connected = false;
  whatsappStatus.qrCode = null;
  console.log('WhatsApp disconnected');
  res.json({ success: true, message: 'WhatsApp disconnected' });
});

app.post('/api/whatsapp/restart', (req, res) => {
  whatsappStatus.connected = false;
  whatsappStatus.qrCode = null;
  console.log('WhatsApp client restarting...');
  res.json({ success: true, message: 'WhatsApp client restarting' });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Server error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 AJ Sender Backend running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📱 WhatsApp QR: http://localhost:${PORT}/api/whatsapp/qr`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down gracefully...');
  if (db) {
    db.close();
  }
  process.exit(0);
});
