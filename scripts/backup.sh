#!/bin/bash

# AJ Sender Backup Script
# This script creates backups of the database and WhatsApp session

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="ajsender_backup_${TIMESTAMP}"

print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Create backup directory
mkdir -p "${BACKUP_DIR}"

print_status "Starting backup process..."

# Stop containers temporarily
print_status "Stopping containers for consistent backup..."
docker-compose down

# Create backup archive
print_status "Creating backup archive..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    --exclude="node_modules" \
    --exclude=".git" \
    --exclude="logs" \
    --exclude="tmp" \
    data/ whatsapp-session/ .env docker-compose.yml

# Restart containers
print_status "Restarting containers..."
docker-compose up -d

# Verify backup
if [ -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
    print_success "Backup completed successfully!"
    print_success "Backup file: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
    
    # Clean old backups (keep last 10)
    print_status "Cleaning old backups..."
    cd "${BACKUP_DIR}"
    ls -t ajsender_backup_*.tar.gz | tail -n +11 | xargs -r rm --
    print_success "Backup cleanup completed"
else
    print_error "Backup failed!"
    exit 1
fi

print_success "Backup process completed successfully!"
