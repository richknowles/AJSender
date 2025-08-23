import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { whatsappService, Contact } from './services/whatsappService';

const app = express();
const PORT = parseInt(process.env.PORT || '3002', 10);

// Configure multer for file uploads
const upload = multer({ dest: '/tmp/' });

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  const status = whatsappService.getStatus();
  res.json({
    ok: true,
    waReady: status.isReady,
    hasQRCode: status.hasQRCode,
    queueLength: status.queueLength,
    timestamp: new Date().toISOString()
  });
});

// Get QR code for WhatsApp Web authentication
app.get('/qr', (req, res) => {
  const qrCode = whatsappService.getQRCode();
  if (qrCode) {
    res.json({ qrCode });
  } else {
    res.json({ qrCode: null, message: 'No QR code available or already authenticated' });
  }
});

// Send single message
app.post('/send-message', async (req, res) => {
  try {
    const { phone, name, message } = req.body;
    
    if (!phone || !message) {
      return res.status(400).json({ error: 'Phone and message are required' });
    }

    const contact: Contact = { phone, name };
    const result = await whatsappService.sendMessage(contact, message);
    
    res.json({ success: true, result });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ 
      error: 'Failed to send message',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Send bulk messages
app.post('/send-bulk', async (req, res) => {
  try {
    const { contacts, message } = req.body;
    
    if (!contacts || !Array.isArray(contacts) || !message) {
      return res.status(400).json({ error: 'Contacts array and message are required' });
    }

    const results = await whatsappService.sendBulkMessages(contacts, message);
    
    const summary = {
      total: results.length,
      sent: results.filter(r => r.status === 'sent').length,
      failed: results.filter(r => r.status === 'failed').length
    };

    res.json({ success: true, summary, results });
  } catch (error) {
    console.error('Bulk send error:', error);
    res.status(500).json({ 
      error: 'Failed to send bulk messages',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Upload and parse CSV
app.post('/upload-csv', upload.single('csv'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No CSV file uploaded' });
    }

    // Read and parse CSV file
    const fs = require('fs');
    const csvContent = fs.readFileSync(req.file.path, 'utf-8');
    
    const lines = csvContent.split('\n').filter((line: string) => line.trim());
    const contacts: Contact[] = [];
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      
      const [phone, name] = line.split(',').map((item: string) => item.trim().replace(/"/g, ''));
      
      if (phone) {
        contacts.push({ phone, name: name || undefined });
      }
    }

    // Clean up uploaded file
    fs.unlinkSync(req.file.path);

    res.json({ 
      success: true, 
      contacts,
      count: contacts.length 
    });
  } catch (error) {
    console.error('CSV upload error:', error);
    res.status(500).json({ 
      error: 'Failed to process CSV file',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`WhatsApp server running on port ${PORT}`);
});
