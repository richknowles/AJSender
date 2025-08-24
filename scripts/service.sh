#!/bin/bash

# AJ Sender Service Management Script
# Provides easy service management commands

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
    echo "  logs <service> Show logs for specific service"
    echo "  health        Check service health"
    echo "  update        Update application"
    echo "  backup        Create backup"
    echo "  restore <file> Restore from backup"
    echo "  ssl <domain>  Setup SSL for domain"
    echo "  monitor       Run system monitor"
    echo "  install       Fresh installation"
    echo
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs backend"
    echo "  $0 ssl sender.ajricardo.com"
    echo "  $0 restore backups/ajsender_backup_20240101_120000.tar.gz"
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
        ./scripts/monitor.sh
        ;;
    
    update)
        print_status "Running update..."
        ./scripts/update.sh
        ;;
    
    backup)
        print_status "Creating backup..."
        ./scripts/backup.sh
        ;;
    
    restore)
        if [ -n "$2" ]; then
            print_status "Restoring from $2..."
            ./scripts/restore.sh "$2"
        else
            print_error "Please specify backup file"
            show_usage
            exit 1
        fi
        ;;
    
    ssl)
        if [ -n "$2" ]; then
            print_status "Setting up SSL for $2..."
            ./scripts/setup-ssl.sh "$2"
        else
            print_error "Please specify domain"
            show_usage
            exit 1
        fi
        ;;
    
    monitor)
        print_status "Running system monitor..."
        ./scripts/monitor.sh
        ;;
    
    install)
        print_status "Running fresh installation..."
        ./scripts/install.sh
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
