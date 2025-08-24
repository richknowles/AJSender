#!/bin/bash

# AJ Sender Complete Installation Script
# One-command installation for fresh servers

set -e

print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        print_status "Run as a regular user with sudo privileges"
        exit 1
    fi
}

# Install Docker and Docker Compose
install_docker() {
    print_status "Installing Docker and Docker Compose..."
    
    # Check if Docker is already installed
    if command -v docker > /dev/null 2>&1; then
        print_success "Docker is already installed"
    else
        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        print_success "Docker installed successfully"
    fi
    
    # Check if Docker Compose is already installed
    if command -v docker-compose > /dev/null 2>&1; then
        print_success "Docker Compose is already installed"
    else
        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose installed successfully"
    fi
}

# Install system dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
    # Update package list
    sudo apt-get update
    
    # Install required packages
    sudo apt-get install -y \
        curl \
        wget \
        git \
        htop \
        unzip \
        jq \
        nginx-utils \
        certbot
    
    print_success "System dependencies installed"
}

# Setup firewall
setup_firewall() {
    print_status "Configuring firewall..."
    
    # Enable UFW
    sudo ufw --force enable
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Show status
    sudo ufw status
    
    print_success "Firewall configured"
}

# Create application user and directories
setup_app_structure() {
    print_status "Setting up application structure..."
    
    # Create directories
    mkdir -p data whatsapp-session logs scripts backups
    
    # Set permissions
    chmod 755 data whatsapp-session logs backups
    chmod +x scripts/*.sh
    
    print_success "Application structure created"
}

# Configure environment
setup_environment() {
    print_status "Setting up environment configuration..."
    
    # Copy environment file if it doesn't exist
    if [ ! -f .env ]; then
        cp .env.example .env
        print_status "Environment file created from template"
        print_warning "Please review and update .env file with your configuration"
    fi
    
    print_success "Environment configuration ready"
}

# Start services
start_services() {
    print_status "Starting AJ Sender services..."
    
    # Build and start containers
    docker-compose up -d --build
    
    print_success "Services started successfully"
}

# Main installation function
main() {
    echo "============================================="
    echo "🚀 AJ Sender Complete Installation"
    echo "Installing WhatsApp Bulk Messaging Platform"
    echo "============================================="
    
    check_root
    
    print_status "Starting installation process..."
    echo
    
    install_dependencies
    echo
    
    install_docker
    echo
    
    setup_firewall
    echo
    
    setup_app_structure
    echo
    
    setup_environment
    echo
    
    start_services
    echo
    
    print_status "Waiting for services to start..."
    sleep 15
    
    # Run verification
    if ./scripts/verify-deployment.sh; then
        print_success "✅ Installation completed successfully!"
        echo
        print_status "🎉 AJ Sender is now running!"
        print_status "Access your application at: http://$(curl -s ifconfig.me):3000"
        print_status "API endpoint: http://$(curl -s ifconfig.me):3001"
        echo
        print_warning "Next steps:"
        print_status "1. Review and update .env file"
        print_status "2. Setup SSL with: ./scripts/setup-ssl.sh your-domain.com"
        print_status "3. Configure WhatsApp connection in the web interface"
        echo
        print_status "Documentation: https://github.com/ajricardo/ajsender"
    else
        print_error "❌ Installation verification failed!"
        print_error "Please check the logs and try again"
        exit 1
    fi
    
    echo "============================================="
}

# Run installation
main "$@"
