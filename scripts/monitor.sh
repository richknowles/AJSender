#!/bin/bash

# AJ Sender Monitoring Script
# Monitors system health and sends alerts

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

# Check if containers are running
check_containers() {
    print_status "Checking container status..."
    
    SERVICES=("frontend" "backend" "caddy")
    ALL_HEALTHY=true
    
    for service in "${SERVICES[@]}"; do
        if docker-compose ps | grep -q "${service}.*Up"; then
            print_success "${service}: Running"
        else
            print_error "${service}: Not running"
            ALL_HEALTHY=false
        fi
    done
    
    return $ALL_HEALTHY
}

# Check API health
check_api_health() {
    print_status "Checking API health..."
    
    if curl -sf http://localhost:3001/health > /dev/null; then
        print_success "API: Healthy"
        return 0
    else
        print_error "API: Unhealthy"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    print_status "Checking disk space..."
    
    USAGE=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$USAGE" -lt 80 ]; then
        print_success "Disk space: ${USAGE}% used"
    elif [ "$USAGE" -lt 90 ]; then
        print_warning "Disk space: ${USAGE}% used (Warning)"
    else
        print_error "Disk space: ${USAGE}% used (Critical)"
        return 1
    fi
    
    return 0
}

# Check memory usage
check_memory() {
    print_status "Checking memory usage..."
    
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    
    if [ "$MEMORY_USAGE" -lt 80 ]; then
        print_success "Memory usage: ${MEMORY_USAGE}%"
    elif [ "$MEMORY_USAGE" -lt 90 ]; then
        print_warning "Memory usage: ${MEMORY_USAGE}% (Warning)"
    else
        print_error "Memory usage: ${MEMORY_USAGE}% (Critical)"
        return 1
    fi
    
    return 0
}

# Main monitoring function
main() {
    echo "===========================================" 
    echo "🔍 AJ Sender System Health Check"
    echo "$(date)"
    echo "==========================================="
    
    OVERALL_HEALTH=0
    
    check_containers || OVERALL_HEALTH=1
    echo
    
    check_api_health || OVERALL_HEALTH=1
    echo
    
    check_disk_space || OVERALL_HEALTH=1
    echo
    
    check_memory || OVERALL_HEALTH=1
    echo
    
    if [ $OVERALL_HEALTH -eq 0 ]; then
        print_success "✅ All systems healthy!"
    else
        print_error "❌ System issues detected!"
    fi
    
    echo "==========================================="
    
    return $OVERALL_HEALTH
}

# Run monitoring
main

# If running in cron mode, restart unhealthy services
if [ "$1" = "--auto-restart" ] && [ $? -ne 0 ]; then
    print_warning "Auto-restart mode: Attempting to restart services..."
    docker-compose restart
    sleep 30
    main
fi
