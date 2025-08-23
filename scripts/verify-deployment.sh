#!/bin/bash

# AJ Sender Deployment Verification Script
# Verifies that the deployment is working correctly

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

# Test functions
test_backend_health() {
    print_status "Testing backend health endpoint..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://localhost:3001/health > /dev/null 2>&1; then
            print_success "Backend health check passed"
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts - Backend not ready, waiting..."
        sleep 2
        ((attempt++))
    done
    
    print_error "Backend health check failed after $max_attempts attempts"
    return 1
}

test_frontend_access() {
    print_status "Testing frontend accessibility..."
    
    if curl -sf http://localhost:3000 > /dev/null 2>&1; then
        print_success "Frontend is accessible"
        return 0
    else
        print_error "Frontend is not accessible"
        return 1
    fi
}

test_api_endpoints() {
    print_status "Testing API endpoints..."
    
    # Test status endpoint
    if curl -sf http://localhost:3001/api/status > /dev/null 2>&1; then
        print_success "Status endpoint: OK"
    else
        print_error "Status endpoint: Failed"
        return 1
    fi
    
    # Test metrics endpoint
    if curl -sf http://localhost:3001/api/metrics > /dev/null 2>&1; then
        print_success "Metrics endpoint: OK"
    else
        print_error "Metrics endpoint: Failed"
        return 1
    fi
    
    # Test contacts endpoint
    if curl -sf http://localhost:3001/api/contacts > /dev/null 2>&1; then
        print_success "Contacts endpoint: OK"
    else
        print_error "Contacts endpoint: Failed"
        return 1
    fi
    
    return 0
}

test_database_connection() {
    print_status "Testing database connection..."
    
    # Check if database file exists and is readable
    if docker-compose exec -T backend test -f /app/data/ajsender.sqlite; then
        print_success "Database file exists"
    else
        print_warning "Database file not found (will be created on first use)"
    fi
    
    # Test database via API
    local response=$(curl -s http://localhost:3001/api/metrics 2>/dev/null || echo "failed")
    if [ "$response" != "failed" ] && echo "$response" | grep -q "totalContacts"; then
        print_success "Database connection: OK"
        return 0
    else
        print_error "Database connection: Failed"
        return 1
    fi
}

test_file_permissions() {
    print_status "Testing file permissions..."
    
    # Check data directory permissions
    if docker-compose exec -T backend test -w /app/data; then
        print_success "Data directory: Writable"
    else
        print_error "Data directory: Not writable"
        return 1
    fi
    
    # Check session directory permissions
    if docker-compose exec -T backend test -w /app/whatsapp-session; then
        print_success "Session directory: Writable"
    else
        print_error "Session directory: Not writable"
        return 1
    fi
    
    return 0
}

test_container_logs() {
    print_status "Checking container logs for errors..."
    
    # Check backend logs
    local backend_errors=$(docker-compose logs backend 2>&1 | grep -i error | wc -l)
    if [ "$backend_errors" -eq 0 ]; then
        print_success "Backend logs: No errors"
    else
        print_warning "Backend logs: $backend_errors error(s) found"
    fi
    
    # Check frontend logs
    local frontend_errors=$(docker-compose logs frontend 2>&1 | grep -i error | wc -l)
    if [ "$frontend_errors" -eq 0 ]; then
        print_success "Frontend logs: No errors"
    else
        print_warning "Frontend logs: $frontend_errors error(s) found"
    fi
}

# Main verification function
main() {
    echo "============================================="
    echo "🔍 AJ Sender Deployment Verification"
    echo "$(date)"
    echo "============================================="
    
    local overall_status=0
    
    # Wait for containers to be ready
    print_status "Waiting for containers to start..."
    sleep 10
    
    # Run tests
    test_backend_health || overall_status=1
    echo
    
    test_frontend_access || overall_status=1
    echo
    
    test_api_endpoints || overall_status=1
    echo
    
    test_database_connection || overall_status=1
    echo
    
    test_file_permissions || overall_status=1
    echo
    
    test_container_logs
    echo
    
    # Final result
    if [ $overall_status -eq 0 ]; then
        print_success "✅ All verification tests passed!"
        print_success "🚀 AJ Sender is ready to use!"
        echo
        print_status "Access your application at:"
        print_status "• Frontend: http://localhost:3000"
        print_status "• Backend API: http://localhost:3001"
        print_status "• Health Check: http://localhost:3001/health"
    else
        print_error "❌ Some verification tests failed!"
        print_error "Please check the logs and fix any issues before proceeding."
        echo
        print_status "Debug commands:"
        print_status "• Check logs: docker-compose logs"
        print_status "• Restart services: docker-compose restart"
        print_status "• View status: docker-compose ps"
    fi
    
    echo "============================================="
    
    return $overall_status
}

# Run verification
main "$@"
