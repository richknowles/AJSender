#!/bin/bash

echo "💕 AJ Sender Setup and Startup Script 💕"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PINK='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1 💕"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_yay() {
    echo -e "${PINK}[YAY]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_success "Docker is running"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose is not installed. Please install it and try again."
    exit 1
fi

print_success "docker-compose is available"

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p whatsapp-session data uploads caddy

print_success "Directories created"

# Set permissions
print_status "Setting permissions..."
chmod 755 whatsapp-session data uploads
chmod +x setup-and-start.sh

# Check if required files exist
print_status "Checking required files..."

required_files=(
    "docker-compose.yml"
    "backend/Dockerfile"
    "backend/package.json"
    "backend/server.js"
    "frontend/Dockerfile"
    "frontend/package.json"
    "frontend/src/App.tsx"
    "caddy/Caddyfile"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    print_error "Missing required files:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    print_warning "Please create these files using the provided commands before running this script."
    exit 1
fi

print_success "All required files are present"

# Stop any existing containers
print_status "Stopping existing containers..."
docker-compose down --remove-orphans

# Build and start services
print_yay "Building and starting services..."
docker-compose up --build -d

# Wait for services to start
print_status "Waiting for services to start..."
sleep 15

# Check service health
print_status "Checking service health..."

# Check backend health
if curl -f http://localhost:3001/health > /dev/null 2>&1; then
    print_success "Backend is healthy and ready"
else
    print_warning "Backend health check failed - this might be normal during startup"
fi

# Check frontend health
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    print_success "Frontend is healthy and beautiful"
else
    print_warning "Frontend health check failed - this might be normal during startup"
fi

# Check if Caddy is running
if docker-compose ps caddy | grep -q "Up"; then
    print_success "Caddy is running and ready to serve"
else
    print_error "Caddy is not running"
fi

# Display status
echo ""
print_yay "Service Status:"
echo "========================="
docker-compose ps

echo ""
print_yay "Access URLs:"
echo "============"
echo "Local Backend: http://localhost:3001"
echo "Local Frontend: http://localhost:3000"
echo "Production: https://sender.ajricardo.com"
echo "Code Server: https://code.dev.alisium.run"

echo ""
print_yay "Next Steps:"
echo "=========================="
echo "1. 💕 Visit https://sender.ajricardo.com to access your beautiful dashboard"
echo "2. 📱 Go to the WhatsApp tab to authenticate your account"
echo "3. 👥 Upload contacts via CSV in the Contacts tab"
echo "4. 💌 Create and send campaigns in the Campaigns tab"
echo "5. 📊 Monitor your metrics in the Dashboard"

echo ""
echo "🔧 Useful Commands:"
echo "==================="
echo "View logs: docker-compose logs -f [service_name]"
echo "Restart services: docker-compose restart"
echo "Stop services: docker-compose down"
echo "Rebuild services: docker-compose up --build -d"
echo "Enter backend container: docker-compose exec backend sh"
echo "Enter frontend container: docker-compose exec frontend sh"

echo ""
print_yay "Setup complete! Your AJ Sender application is ready to connected!✨"
echo ""
echo "🌟 Features included:"
echo "• Animated graphics"
echo "• Beautiful gradient design 🌈"
echo "• WhatsApp QR authentication 📱"
echo "• CSV contact upload 📋"
echo "• Campaign management "
echo "• Real-time metrics 📊"
echo "• Colorful UI/UX"
