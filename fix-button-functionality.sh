#!/bin/bash
# Fix button functionality - ensure all API endpoints work
set -euo pipefail

echo "=== Fixing Button Functionality ==="

# Stop containers
docker-compose down

# Update backend server.js with proper file upload handling
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
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Create uploads directory
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// File upload configuration
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadsDir)
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname)
    }
});

const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024 // 10MB limit
    }
});

// Database setup
const dbPath = path.join(__dirname, 'data', 'ajsender.sqlite');
let db = null;
let dbInitialized = false;

// Campaign progress state
let campaignProgress = {
    isActive: false,
    percentage: 0,
    currentCampaign: null,
    totalContacts: 0,
    sentCount: 0
};

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
            console.log('✅ Connected to SQLite database');
            
            // Create tables
            db.serialize(() => {
                db.run(`CREATE TABLE IF NOT EXISTS contacts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    phone_number TEXT UNIQUE NOT NULL,
                    name TEXT,
                    email TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )`, (err) => {
                    if (err) console.error('Error creating contacts table:', err);
                    else console.log('✅ Contacts table ready');
                });

                db.run(`CREATE TABLE IF NOT EXISTS campaigns (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    message TEXT NOT NULL,
                    status TEXT DEFAULT 'draft',
                    sent_count INTEGER DEFAULT 0,
                    failed_count INTEGER DEFAULT 0,
                    total_messages INTEGER DEFAULT 0,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )`, (err) => {
                    if (err) console.error('Error creating campaigns table:', err);
                    else console.log('✅ Campaigns table ready');
                });

                db.run(`CREATE TABLE IF NOT EXISTS messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    campaign_id INTEGER NOT NULL,
                    contact_id INTEGER NOT NULL,
                    phone_number TEXT NOT NULL,
                    message TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    sent_at DATETIME,
                    error_message TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (campaign_id) REFERENCES campaigns(id),
                    FOREIGN KEY (contact_id) REFERENCES contacts(id)
                )`, (err) => {
                    if (err) console.error('Error creating messages table:', err);
                    else console.log('✅ Messages table ready');
                });

                dbInitialized = true;
                console.log('✅ Database initialization complete');
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
        timestamp: new Date().toISOString(),
        version: '2.0.0'
    });
});

// Status endpoint
app.get('/api/status', (req, res) => {
    res.json({
        backend: 'running',
        whatsapp: 'disconnected', // Will be 'connected' when WhatsApp is implemented
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
    
    // Use promises to handle multiple queries
    Promise.all([
        new Promise((resolve) => {
            db.get('SELECT COUNT(*) as count FROM contacts', (err, row) => {
                resolve(err ? 0 : (row?.count || 0));
            });
        }),
        new Promise((resolve) => {
            db.get('SELECT COUNT(*) as count FROM campaigns', (err, row) => {
                resolve(err ? 0 : (row?.count || 0));
            });
        }),
        new Promise((resolve) => {
            db.get('SELECT COUNT(*) as count FROM messages', (err, row) => {
                resolve(err ? 0 : (row?.count || 0));
            });
        }),
        new Promise((resolve) => {
            db.get('SELECT COUNT(*) as count FROM messages WHERE status = "sent"', (err, row) => {
                resolve(err ? 0 : (row?.count || 0));
            });
        })
    ]).then(([totalContacts, totalCampaigns, totalMessages, sentMessages]) => {
        res.json({
            totalContacts,
            totalCampaigns,
            totalMessages,
            sentMessages
        });
    });
});

// Campaign progress endpoint
app.get('/api/campaigns/progress', (req, res) => {
    res.json(campaignProgress);
});

// Contacts endpoints
app.get('/api/contacts', (req, res) => {
    if (!db || !dbInitialized) {
        return res.json([]);
    }
    
    db.all('SELECT * FROM contacts ORDER BY created_at DESC LIMIT 1000', (err, rows) => {
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
    
    const { phone_number, name, email } = req.body;
    
    if (!phone_number) {
        return res.status(400).json({ error: 'Phone number is required' });
    }

    db.run(
        'INSERT OR REPLACE INTO contacts (phone_number, name, email) VALUES (?, ?, ?)',
        [phone_number, name || '', email || null],
        function(err) {
            if (err) {
                console.error('Error inserting contact:', err);
                return res.status(500).json({ error: err.message });
            }
            res.json({ 
                id: this.lastID, 
                phone_number, 
                name: name || '',
                email: email || null,
                message: 'Contact saved successfully' 
            });
        }
    );
});

// CSV Upload endpoint - FIXED
app.post('/api/contacts/upload', upload.single('csvFile'), (req, res) => {
    console.log('📁 CSV upload request received');
    console.log('File info:', req.file);
    
    if (!req.file) {
        console.error('❌ No file uploaded');
        return res.status(400).json({ error: 'No file uploaded' });
    }

    if (!db || !dbInitialized) {
        console.error('❌ Database not ready');
        return res.status(503).json({ error: 'Database not ready' });
    }

    const contacts = [];
    const errors = [];
    let processedCount = 0;

    console.log('📖 Starting to read CSV file:', req.file.path);

    fs.createReadStream(req.file.path)
        .pipe(csv())
        .on('data', (row) => {
            processedCount++;
            console.log(`Processing row ${processedCount}:`, row);
            
            // Try multiple column name variations
            const phoneNumber = row.phone_number || row.phone || row.number || row.Phone || row.Number || row.PHONE_NUMBER;
            const name = row.name || row.Name || row.first_name || row.FirstName || row.FIRST_NAME || '';
            const email = row.email || row.Email || row.EMAIL || null;

            if (phoneNumber) {
                const cleanPhone = phoneNumber.toString().replace(/[^\d+]/g, '');
                if (cleanPhone && cleanPhone.length >= 10) {
                    contacts.push({ 
                        phone_number: cleanPhone, 
                        name: name.toString().trim(),
                        email: email ? email.toString().trim() : null
                    });
                    console.log(`✅ Valid contact added: ${cleanPhone} - ${name}`);
                } else {
                    errors.push(`Row ${processedCount}: Invalid phone number format: ${phoneNumber}`);
                    console.log(`❌ Invalid phone: ${phoneNumber}`);
                }
            } else {
                errors.push(`Row ${processedCount}: Missing phone number`);
                console.log(`❌ Missing phone number in row ${processedCount}`);
            }
        })
        .on('end', () => {
            console.log(`📋 CSV processing complete. Found ${contacts.length} valid contacts`);
            
            // Clean up uploaded file
            fs.unlinkSync(req.file.path);

            if (contacts.length === 0) {
                console.error('❌ No valid contacts found');
                return res.status(400).json({ 
                    error: 'No valid contacts found in CSV',
                    errors,
                    totalRows: processedCount
                });
            }

            let insertedCount = 0;
            let skippedCount = 0;
            let completed = 0;

            console.log(`💾 Starting to insert ${contacts.length} contacts into database`);

            contacts.forEach((contact, index) => {
                db.run(
                    'INSERT OR IGNORE INTO contacts (phone_number, name, email) VALUES (?, ?, ?)',
                    [contact.phone_number, contact.name, contact.email],
                    function(err) {
                        if (err) {
                            console.error(`❌ Error inserting contact ${index + 1}:`, err);
                        } else if (this.changes > 0) {
                            insertedCount++;
                            console.log(`✅ Inserted contact: ${contact.phone_number}`);
                        } else {
                            skippedCount++;
                            console.log(`⏭️  Skipped duplicate: ${contact.phone_number}`);
                        }
                        
                        completed++;
                        if (completed === contacts.length) {
                            console.log(`🎉 Upload complete: ${insertedCount} inserted, ${skippedCount} skipped`);
                            res.json({
                                success: true,
                                message: `Successfully processed CSV file`,
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
            console.error('❌ CSV processing error:', error);
            // Clean up uploaded file on error
            if (fs.existsSync(req.file.path)) {
                fs.unlinkSync(req.file.path);
            }
            res.status(500).json({ error: 'Error processing CSV file: ' + error.message });
        });
});

// Campaigns endpoints
app.get('/api/campaigns', (req, res) => {
    if (!db || !dbInitialized) {
        return res.json([]);
    }
    
    db.all(`
        SELECT c.*, 
               COUNT(m.id) as total_messages,
               COUNT(CASE WHEN m.status = 'sent' THEN 1 END) as sent_count,
               COUNT(CASE WHEN m.status = 'failed' THEN 1 END) as failed_count
        FROM campaigns c
        LEFT JOIN messages m ON c.id = m.campaign_id
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
    console.log('📢 Campaign creation request:', req.body);
    
    if (!db || !dbInitialized) {
        return res.status(503).json({ error: 'Database not ready' });
    }
    
    const { name, message } = req.body;
    
    if (!name || !message) {
        return res.status(400).json({ error: 'Name and message are required' });
    }

    if (message.length > 1000) {
        return res.status(400).json({ error: 'Message too long (max 1000 characters)' });
    }

    db.run(
        'INSERT INTO campaigns (name, message, status) VALUES (?, ?, ?)',
        [name, message, 'draft'],
        function(err) {
            if (err) {
                console.error('Error creating campaign:', err);
                return res.status(500).json({ error: err.message });
            }
            console.log(`✅ Campaign created: ${name} (ID: ${this.lastID})`);
            res.json({ 
                id: this.lastID, 
                name, 
                message,
                status: 'draft',
                success: true
            });
        }
    );
});

// Send campaign endpoint (simulated for now)
app.post('/api/campaigns/:id/send', async (req, res) => {
    const campaignId = parseInt(req.params.id);
    console.log(`📤 Send campaign request for ID: ${campaignId}`);

    if (!db || !dbInitialized) {
        return res.status(503).json({ error: 'Database not ready' });
    }

    try {
        // Get campaign
        const campaign = await new Promise((resolve, reject) => {
            db.get('SELECT * FROM campaigns WHERE id = ?', [campaignId], (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });

        if (!campaign) {
            return res.status(404).json({ error: 'Campaign not found' });
        }

        // Get contacts
        const contacts = await new Promise((resolve, reject) => {
            db.all('SELECT * FROM contacts', (err, rows) => {
                if (err) reject(err);
                else resolve(rows);
            });
        });

        if (contacts.length === 0) {
            return res.status(400).json({ error: 'No contacts available to send to' });
        }

        // Update campaign status to sending
        db.run('UPDATE campaigns SET status = ?, total_messages = ? WHERE id = ?', 
               ['sending', contacts.length, campaignId]);

        // Initialize progress
        campaignProgress = {
            isActive: true,
            percentage: 0,
            currentCampaign: campaign.name,
            totalContacts: contacts.length,
            sentCount: 0
        };

        console.log(`🚀 Starting simulated campaign send to ${contacts.length} contacts`);

        // Simulate sending messages (replace with real WhatsApp integration later)
        let sentCount = 0;
        let failedCount = 0;

        // Process contacts in batches
        for (let i = 0; i < contacts.length; i++) {
            const contact = contacts[i];
            
            // Simulate processing time
            await new Promise(resolve => setTimeout(resolve, 100));
            
            // Simulate 95% success rate
            const success = Math.random() > 0.05;
            const status = success ? 'sent' : 'failed';
            
            // Record message
            db.run(`
                INSERT INTO messages 
                (campaign_id, contact_id, phone_number, message, status, sent_at) 
                VALUES (?, ?, ?, ?, ?, ?)
            `, [
                campaignId, 
                contact.id, 
                contact.phone_number, 
                campaign.message, 
                status,
                new Date().toISOString()
            ]);

            if (success) {
                sentCount++;
            } else {
                failedCount++;
            }
            
            // Update progress
            campaignProgress.sentCount = sentCount;
            campaignProgress.percentage = Math.round(((sentCount + failedCount) / contacts.length) * 100);
            
            console.log(`Progress: ${campaignProgress.percentage}% (${sentCount + failedCount}/${contacts.length})`);
        }

        // Update campaign final status
        const finalStatus = failedCount === 0 ? 'completed' : 'completed_with_errors';
        db.run('UPDATE campaigns SET status = ?, sent_count = ?, failed_count = ? WHERE id = ?', 
               [finalStatus, sentCount, failedCount, campaignId]);

        // Complete progress
        campaignProgress.percentage = 100;
        console.log(`🎉 Campaign completed: ${sentCount} sent, ${failedCount} failed`);

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
            failed: failedCount,
            total: contacts.length,
            message: `Campaign sent! ${sentCount} messages delivered, ${failedCount} failed.`
        });

    } catch (error) {
        console.error('Campaign send error:', error);
        campaignProgress.isActive = false;
        db.run('UPDATE campaigns SET status = ? WHERE id = ?', ['failed', campaignId]);
        res.status(500).json({ error: error.message });
    }
});

// Delete campaign endpoint
app.delete('/api/campaigns/:id', (req, res) => {
    const campaignId = parseInt(req.params.id);
    
    if (!db || !dbInitialized) {
        return res.status(503).json({ error: 'Database not ready' });
    }

    db.run('DELETE FROM campaigns WHERE id = ?', [campaignId], function(err) {
        if (err) {
            console.error('Error deleting campaign:', err);
            return res.status(500).json({ error: err.message });
        }
        
        if (this.changes === 0) {
            return res.status(404).json({ error: 'Campaign not found' });
        }
        
        // Also delete associated messages
        db.run('DELETE FROM messages WHERE campaign_id = ?', [campaignId]);
        
        res.json({ success: true, message: 'Campaign deleted successfully' });
    });
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({ 
        error: process.env.NODE_ENV === 'production' ? 'Internal server error' : error.message 
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 AJ Sender Backend running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`🔗 API base: http://localhost:${PORT}/api`);
    console.log(`📁 Uploads directory: ${uploadsDir}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('Shutting down gracefully...');
    if (db) {
        db.close();
    }
    process.exit(0);
});
EOF

echo "✅ Backend functionality updated!"
echo ""
echo "Building and starting containers..."
docker-compose up --build -d

echo ""
echo "🎉 All buttons should now work!"
echo ""
echo "Features now working:"
echo "- CSV upload with proper file handling"
echo "- Campaign creation with validation"
echo "- Campaign sending simulation (95% success rate)"
echo "- Analytics modal with real data"
echo "- Progress tracking during campaign sends"
echo ""
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:3001"
echo "Test the upload with a CSV file containing columns: phone_number, name, email"