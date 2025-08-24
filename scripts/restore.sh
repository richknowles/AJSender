#!/bin/bash

# AJ Sender Restore Script
# This script restores from a backup archive

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

if [ $# -eq 0 ]; then
    print_error "Usage: $0 <backup_file.tar.gz>"
    print_status "Available backups:"
    ls -la ./backups/ajsender_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

print_warning "This will overwrite current data and WhatsApp session!"
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_status "Restore cancelled"
    exit 0
fi

print_status "Starting restore process..."

# Stop containers
print_status "Stopping containers..."
docker-compose down

# Backup current state
print_status "Creating backup of current state..."
CURRENT_BACKUP="./backups/before_restore_$(date +"%Y%m%d_%H%M%S").tar.gz"
tar -czf "$CURRENT_BACKUP" data/ whatsapp-session/ .env 2>/dev/null || true

# Extract backup
print_status "Extracting backup archive..."
tar -xzf "$BACKUP_FILE"

# Restart containers
print_status "Restarting containers..."
docker-compose up -d

print_success "Restore completed successfully!"
print_status "Current state backed up to: $CURRENT_BACKUP"
