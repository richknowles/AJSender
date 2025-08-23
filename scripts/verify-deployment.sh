#!/bin/bash

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

test_backend_health() {
    print_status "Testing backend health..."
    
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
    
    print_error "Backend health check failed"
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
    
    if curl -sf http://localhost:3001/api/status > /dev/null 2>&1; then
        print_success "Status endpoint: OK"
    else
        print_error "Status endpoint: Failed"
        return 1
    fi
    
    if curl -sf http://localhost:3001/api/metrics > /dev/null 2>&1; then
        print_success "Metrics endpoint: OK"
    else
        print_error "Metrics endpoint: Failed"
        return 1
    fi
    
    return 0
}

main() {
    echo "============================================="
    echo "🔍 AJ Sender Deployment Verification"
    echo "$(date)"
    echo "============================================="
    
    local overall_status=0
    
    print_status "Waiting for containers to start..."
    sleep 10
    
    test_backend_health || overall_status=1
    echo
    
    test_frontend_access || overall_status=1
    echo
    
    test_api_endpoints || overall_status=1
    echo
    
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
        print_error "Please check the logs and fix any issues."
        echo
        print_status "Debug commands:"
        print_status "• Check logs: docker-compose logs"
        print_status "• Restart services: docker-compose restart"
        print_status "• View status: docker-compose ps"
    fi
    
    echo "============================================="
    
    return $overall_status
}

main "$@"
