const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Simple health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        message: 'Backend is running! ✨',
        timestamp: new Date().toISOString()
    });
});

// API status
app.get('/api/status', (req, res) => {
    res.json({
        backend: 'running',
        whatsapp: 'disconnected',
        authenticated: false
    });
});

// WhatsApp QR endpoint (mock for now)
app.get('/api/whatsapp/qr', (req, res) => {
    res.json({
        authenticated: false,
        qrCode: null,
        status: 'disconnected',
        message: 'WhatsApp client not initialized yet'
    });
});

// Simple metrics
app.get('/api/metrics', (req, res) => {
    res.json({
        totalContacts: 0,
        totalCampaigns: 0,
        totalMessages: 0,
        sentMessages: 0
    });
});

// Simple contacts endpoint
app.get('/api/contacts', (req, res) => {
    res.json([]);
});

// Simple campaigns endpoint
app.get('/api/campaigns', (req, res) => {
    res.json([]);
});

// Error handling
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`💕 AJ Sender Backend running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});

process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully');
    process.exit(0);
});
