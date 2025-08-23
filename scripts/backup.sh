#!/bin/bash

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

mkdir -p "${BACKUP_DIR}"

print_status "Creating backup archive..."
docker-compose down

tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    --exclude="node_modules" \
    --exclude=".git" \
    --exclude="logs" \
    data/ whatsapp-session/ .env docker-compose.yml

docker-compose up -d

if [ -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
    print_success "Backup completed: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
else
    print_error "Backup failed!"
    exit 1
fi
