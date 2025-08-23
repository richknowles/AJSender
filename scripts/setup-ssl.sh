#!/bin/bash

# AJ Sender SSL Setup Script
# Sets up SSL certificates for production deployment

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

# Check if domain is provided
if [ $# -eq 0 ]; then
    print_error "Usage: $0 <domain>"
    print_status "Example: $0 sender.ajricardo.com"
    exit 1
fi

DOMAIN="$1"

print_status "Setting up SSL for domain: $DOMAIN"

# Validate domain format
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid domain format: $DOMAIN"
    exit 1
fi

# Check if domain resolves to this server
print_status "Checking DNS resolution for $DOMAIN..."
DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "unknown")

if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
    print_success "Domain resolves correctly to this server ($SERVER_IP)"
elif [ "$DOMAIN_IP" = "" ]; then
    print_warning "Domain does not resolve. Make sure DNS is configured correctly."
    read -p "Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        exit 1
    fi
else
    print_warning "Domain resolves to $DOMAIN_IP but server IP is $SERVER_IP"
    read -p "Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        exit 1
    fi
fi

# Update Caddyfile with the correct domain
print_status "Updating Caddyfile with domain configuration..."
sed -i "s/sender\.ajricardo\.com/$DOMAIN/g" caddy/Caddyfile
sed -i "s/www\.sender\.ajricardo\.com/www.$DOMAIN/g" caddy/Caddyfile

print_success "Caddyfile updated with domain: $DOMAIN"

# Update environment file
print_status "Updating environment configuration..."
sed -i "s|CORS_ORIGIN=.*|CORS_ORIGIN=https://$DOMAIN|g" .env

print_success "Environment updated with domain: $DOMAIN"

# Restart Caddy to apply changes
print_status "Restarting Caddy to apply SSL configuration..."
docker-compose restart caddy

# Wait for SSL certificate generation
print_status "Waiting for SSL certificate generation..."
sleep 10

# Check SSL certificate
print_status "Verifying SSL certificate..."
for i in {1..30}; do
    if curl -sf "https://$DOMAIN/health" > /dev/null 2>&1; then
        print_success "SSL certificate generated and working!"
        break
    elif [ $i -eq 30 ]; then
        print_error "SSL certificate generation failed or timed out"
        print_status "Check Caddy logs: docker-compose logs caddy"
        exit 1
    else
        print_status "Attempt $i/30 - Waiting for SSL certificate..."
        sleep 10
    fi
done

# Final verification
print_status "Running final SSL verification..."
SSL_INFO=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null || echo "failed")

if [ "$SSL_INFO" != "failed" ]; then
    print_success "SSL Certificate Details:"
    echo "$SSL_INFO"
    print_success "✅ SSL setup completed successfully!"
    echo
    print_status "Your application is now available at:"
    print_success "🔒 https://$DOMAIN"
else
    print_error "SSL verification failed"
    exit 1
fi
