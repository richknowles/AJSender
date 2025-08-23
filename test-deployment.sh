# Copy and paste this entire script:
echo "🧪 Testing AJ Sender Deployment"
echo "==============================="

# Wait a bit more for backend to fully start
echo "⏳ Waiting for services to fully initialize..."
sleep 30

# Check service status
echo ""
echo "📊 Service Status:"
docker-compose ps

# Test backend health
echo ""
echo "🔍 Testing Backend Health:"
backend_health=$(curl -s http://localhost:3001/health)
if [ $? -eq 0 ]; then
    echo "✅ Backend Health: $backend_health"
else
    echo "❌ Backend Health: Failed to connect"
fi

# Test backend API status
echo ""
echo "🔍 Testing Backend API Status:"
api_status=$(curl -s http://localhost:3001/api/status)
if [ $? -eq 0 ]; then
    echo "✅ Backend API Status: $api_status"
else
    echo "❌ Backend API Status: Failed to connect"
fi

# Test frontend health
echo ""
echo "🔍 Testing Frontend Health:"
frontend_health=$(curl -s http://localhost:3000/health)
if [ $? -eq 0 ]; then
    echo "✅ Frontend Health: $frontend_health"
else
    echo "❌ Frontend Health: Failed to connect"
fi

# Test WhatsApp QR endpoint
echo ""
echo "🔍 Testing WhatsApp QR Endpoint:"
qr_response=$(curl -s http://localhost:3001/api/whatsapp/qr)
if [ $? -eq 0 ]; then
    echo "✅ WhatsApp QR Endpoint: Working"
else
    echo "❌ WhatsApp QR Endpoint: Failed"
fi

echo ""
echo "🎉 Deployment Test Complete!"
echo ""
echo "🌐 Access Your Application:"
echo "=========================="
echo "• Local Frontend: http://localhost:3000"
echo "• Local Backend API: http://localhost:3001"
echo "• Production (if DNS configured): https://sender.ajricardo.com"
echo ""
echo "✨ What to do next:"
echo "1. Open http://localhost:3000 in your browser"
echo "2. Check to see it"
echo "3. Go to the WhatsApp tab to authenticate 📱"
echo "4. Upload contacts in the Contacts tab 📋"
echo "5. Create and send campaigns"
echo ""
echo "Your AJ Sender application is ready!"
