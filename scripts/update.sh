#!/bin/bash

# AJ Sender Update Script
# Updates the application with zero-downtime deployment

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

# Create backup before update
create_backup() {
    print_status "Creating backup before update..."
    ./scripts/backup.sh
    print_success "Backup created successfully"
}

# Pull latest changes
update_code() {
    print_status "Updating application code..."
    
    if [ -d ".git" ]; then
        git pull origin main
        print_success "Code updated from Git repository"
    else
        print_warning "Not a Git repository. Please update code manually."
    fi
}

# Rebuild and restart services
rebuild_services() {

# ===== AJSENDER-DEPLOYMENT-PART-6.SH =====

print_status "Rebuilding and restarting services..."
    
    # Build new images
    docker-compose build --no-cache
    
    # Rolling update with zero downtime
    print_status "Performing rolling update..."
    
    # Update backend first
    docker-compose up -d --no-deps backend
    sleep 10
    
    # Wait for backend to be healthy
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://localhost:3001/health > /dev/null 2>&1; then
            print_success "Backend updated and healthy"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Backend failed to start after update"
            return 1
        fi
        
        print_status "Waiting for backend to be ready... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    # Update frontend
    docker-compose up -d --no-deps frontend
    sleep 5
    
    # Update proxy last
    docker-compose up -d --no-deps caddy
    
    print_success "All services updated successfully"
}

# Clean up old images
cleanup_images() {
    print_status "Cleaning up old Docker images..."
    
    # Remove dangling images
    docker image prune -f
    
    # Remove old images (keep last 3 versions)
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.ID}}" | \
    grep "ajsender" | \
    tail -n +4 | \
    awk '{print $3}' | \
    xargs -r docker rmi -f 2>/dev/null || true
    
    print_success "Image cleanup completed"
}

# Verify update
verify_update() {
    print_status "Verifying update..."
    
    # Run verification script
    if ./scripts/verify-deployment.sh; then
        print_success "Update verification passed"
        return 0
    else
        print_error "Update verification failed"
        return 1
    fi
}

# Main update function
main() {
    echo "============================================="
    echo "🚀 AJ Sender Update Process"
    echo "$(date)"
    echo "============================================="
    
    # Confirm update
    print_warning "This will update AJ Sender to the latest version."
    read -p "Continue with update? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Update cancelled"
        exit 0
    fi
    
    # Run update steps
    create_backup
    echo
    
    update_code
    echo
    
    rebuild_services
    echo
    
    cleanup_images
    echo
    
    verify_update
    echo
    
    print_success "✅ Update completed successfully!"
    print_status "AJ Sender is now running the latest version"
    
    echo "============================================="
}

# Run update
main "$@"
