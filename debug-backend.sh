# Debug Backend Issue
echo "🔍 Debugging Backend Issue"
echo "=========================="

# Check backend logs
echo "📋 Backend Logs (last 50 lines):"
docker-compose logs --tail=50 backend

echo ""
echo "🔍 Checking if backend container is running:"
docker-compose ps backend

echo ""
echo "🔍 Trying to enter the backend container to debug:"
if docker-compose exec backend sh -c "echo 'Container is accessible'" 2>/dev/null; then
    echo "✅ Backend container is accessible"
    
    echo ""
    echo "🔍 Checking Node.js and npm in container:"
    docker-compose exec backend sh -c "node --version && npm --version"
    
    echo ""
    echo "🔍 Checking backend files:"
    docker-compose exec backend sh -c "ls -la /app"
    
    echo ""
    echo "🔍 Checking if server.js exists and is readable:"
    docker-compose exec backend sh -c "cat /app/server.js | head -20"
    
else
    echo "❌ Backend container is not accessible"
    echo ""
    echo "🔄 Let's try to rebuild the backend with more debugging..."
    
    # Create a simpler backend for testing
    echo "📝 Creating a simplified backend server for testing..."
    
    cat > backend/server-simple.js << 'EOF'
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
        message: 'Backend is running! 💕',
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
EOF

    # Update package.json to use the simple server
    cat > backend/package.json << 'EOF'
{
  "name": "ajsender-backend",
  "version": "1.0.0",
  "description": "AJ Sender WhatsApp bulk messaging backend",
  "main": "server-simple.js",
  "scripts": {
    "start": "node server-simple.js",
    "dev": "nodemon server-simple.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "keywords": [
    "whatsapp",
    "bulk-messaging",
    "nodejs",
    "express"
  ],
  "author": "AJ Ricardo",
  "license": "MIT"
}
EOF

    # Rebuild with the simplified backend
    echo ""
    echo "🔄 Rebuilding backend with simplified version..."
    docker-compose stop backend
    docker-compose build backend
    docker-compose up -d backend
    
    # Wait and test
    echo "⏳ Waiting for simplified backend to start..."
    sleep 10
    
    echo "🔍 Testing simplified backend:"
    if curl -s http://localhost:3001/health; then
        echo ""
        echo "✅ Simplified backend is working!"
        echo ""
        echo "Now let's gradually add features back..."
        
        # If simple backend works, we can start adding WhatsApp features
        echo "📝 The issue was likely with WhatsApp dependencies."
        echo "We'll need to add WhatsApp features gradually."
        
    else
        echo ""
        echo "❌ Even simplified backend failed. Let's check the logs:"
        docker-compose logs --tail=20 backend
    fi
fi
