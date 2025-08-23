#!/bin/bash

print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

show_usage() {
    echo "AJ Sender Service Management"
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  start         Start all services"
    echo "  stop          Stop all services"
    echo "  restart       Restart all services"
    echo "  status        Show service status"
    echo "  logs          Show service logs"
    echo "  health        Check service health"
}

case "$1" in
    start)
        print_status "Starting AJ Sender services..."
        docker-compose up -d
        print_success "Services started"
        ;;
    
    stop)
        print_status "Stopping AJ Sender services..."
        docker-compose down
        print_success "Services stopped"
        ;;
    
    restart)
        print_status "Restarting AJ Sender services..."
        docker-compose restart
        print_success "Services restarted"
        ;;
    
    status)
        print_status "Service status:"
        docker-compose ps
        ;;
    
    logs)
        if [ -n "$2" ]; then
            print_status "Showing logs for $2:"
            docker-compose logs -f "$2"
        else
            print_status "Showing all service logs:"
            docker-compose logs -f
        fi
        ;;
    
    health)
        print_status "Running health check..."
        curl -sf http://localhost:3001/health || print_error "Health check failed"
        ;;
    
    ""|--help|-h|help)
        show_usage
        ;;
    
    *)
        print_error "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac
