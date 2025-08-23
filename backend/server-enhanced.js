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
const upload = multer({ dest: '/app/uploads/' });

// Database setup with proper error handling
let db = null;
let dbInitialized = false;

function initializeDatabase() {
    try {
        // Ensure data directory exists with proper permissions
        const dataDir = '/app/data';
        if (!fs.existsSync(dataDir)) {
            fs.mkdirSync(dataDir, { recursive: true, mode: 0o755 });
        }
        
        const dbPath = path.join(dataDir, 'database.sqlite');
        console.log('Initializing database at:', dbPath);
        
        db = new sqlite3.Database(dbPath, (err) => {
            if (err) {
                console.error('Database connection error:', err);
                return;
            }
            console.log('✅ Connected to SQLite database');
            
            // Initialize tables
            db.serialize(() => {
                // Contacts table
                db.run(`CREATE TABLE IF NOT EXISTS contacts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    phone_number TEXT UNIQUE NOT NULL,
                    name TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )`, (err) => {
                    if (err) console.error('Error creating contacts table:', err);
                    else console.log('✅ Contacts table ready');
                });

                // Campaigns table
                db.run(`CREATE TABLE IF NOT EXISTS campaigns (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    message TEXT NOT NULL,
                    status TEXT DEFAULT 'draft',
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )`, (err) => {
                    if (err) console.error('Error creating campaigns table:', err);
                    else console.log('✅ Campaigns table ready');
                });

                dbInitialized = true;
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
        status: 'ok',
        backend: 'running',
        database: dbInitialized ? 'connected' : 'connecting',
        whatsapp: 'offline',
        message: 'Backend with database is running! ✨',
        timestamp: new Date().toISOString()
    });
});

// System status
app.get('/api/status', (req, res) => {
    res.json({
        backend: 'running',
        whatsapp: 'disconnected',
        authenticated: false,
        database: dbInitialized ? 'connected' : 'connecting'
    });
});

// Contact management routes
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
                message: 'Contact saved successfully! ✨' 
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
                                resolve({ success: false, error: err.message });
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
                    message: `Processed ${contacts.length} contacts! ✨`,
                    inserted: insertedCount,
                    skipped: skippedCount,
                    errors: errors.length > 0 ? errors : undefined
                });
            });
        })
        .on('error', (error) => {
            fs.unlinkSync(req.file.path);
            res.status(500).json({ error: 'Error processing CSV file: ' + error.message });
        });
});

// Campaign management routes
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

// Dashboard metrics
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
        totalMessages: 'SELECT COUNT(*) as count FROM campaigns',
        sentMessages: 'SELECT COUNT(*) as count FROM campaigns WHERE status = "completed"'
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

// Mock WhatsApp endpoints (for now)
app.get('/api/whatsapp/qr', (req, res) => {
    res.json({
        authenticated: false,
        qrCode: null,
        status: 'disconnected',
        message: 'WhatsApp integration coming soon! 💕'
    });
});

app.post('/api/whatsapp/logout', (req, res) => {
    res.json({ success: true, message: 'WhatsApp disconnected' });
});

app.post('/api/whatsapp/restart', (req, res) => {
    res.json({ success: true, message: 'WhatsApp client restarting...' });
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`💕 AJ Sender Backend with Database running on port ${PORT}`);
    console.log(`Health check available at http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('Shutting down gracefully...');
    if (db) {
        db.close();
    }
    process.exit(0);
});
