# 🚀 AJ Sender - WhatsApp Bulk Messaging Platform

A professional, production-ready WhatsApp bulk messaging platform built with React, Node.js, and Docker. Designed with love for reliable, scalable messaging campaigns.

![AJ Sender Dashboard](https://via.placeholder.com/800x400/22c55e/ffffff?text=AJ+Sender+Dashboard)

## ✨ Features

- **🔥 Modern UI/UX** - Beautiful, responsive dashboard with dark/light mode
- **📱 WhatsApp Integration** - Send bulk messages via WhatsApp Web
- **📊 Real-time Analytics** - Track campaign progress and success rates
- **📋 Contact Management** - Import contacts from CSV, manage groups
- **🚀 Campaign Management** - Create, schedule, and monitor campaigns
- **🔒 Production Ready** - SSL, monitoring, backups, and auto-scaling
- **📈 Performance Optimized** - Fast loading, efficient resource usage
- **🛡️ Security First** - CORS, rate limiting, input validation
- **🐳 Docker Powered** - Easy deployment and scaling
- **🔧 Zero-Config Setup** - One-command installation

## 🎯 Quick Start

### One-Command Installation

```bash
# Download and run the complete deployment script
curl -fsSL https://raw.githubusercontent.com/ajricardo/ajsender/main/deploy.sh | bash

# Or clone and run locally
git clone https://github.com/ajricardo/ajsender.git
cd ajsender
chmod +x ajs-complete-deployment.sh
./ajs-complete-deployment.sh

# ===== AJSENDER-DEPLOYMENT-PART-7.SH =====

PART 7 (Final):

```bash
# 26. Create post-deployment optimization
print_status "Creating post-deployment optimization script..."
cat > scripts/optimize.sh << 'EOF'
#!/bin/bash

# AJ Sender Post-Deployment Optimization Script
# Optimizes the system for maximum performance

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

# Optimize Docker settings
optimize_docker() {
    print_status "Optimizing Docker configuration..."
    
    # Create Docker daemon configuration
    sudo mkdir -p /etc/docker
    cat > /tmp/daemon.json << 'DOCKER_EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
DOCKER_EOF
    
    sudo mv /tmp/daemon.json /etc/docker/daemon.json
    sudo systemctl restart docker
    
    print_success "Docker optimized"
}

# Optimize system settings
optimize_system() {
    print_status "Optimizing system settings..."
    
    # Increase file descriptor limits
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    
    # Optimize network settings
    cat > /tmp/network-optimization.conf << 'NET_EOF'
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
vm.swappiness = 10
NET_EOF
    
    sudo mv /tmp/network-optimization.conf /etc/sysctl.d/99-ajsender.conf
    sudo sysctl -p /etc/sysctl.d/99-ajsender.conf
    
    print_success "System optimized"
}

# Setup log rotation
setup_log_rotation() {
    print_status "Setting up log rotation..."
    
    cat > /tmp/ajsender-logrotate << 'LOG_EOF'
/path/to/ajsender/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f /path/to/ajsender/docker-compose.yml restart caddy > /dev/null 2>&1 || true
    endscript
}
LOG_EOF
    
    sed -i "s|/path/to/ajsender|$(pwd)|g" /tmp/ajsender-logrotate
    sudo mv /tmp/ajsender-logrotate /etc/logrotate.d/ajsender
    
    print_success "Log rotation configured"
}

# Setup monitoring cron jobs
setup_cron_jobs() {
    print_status "Setting up monitoring cron jobs..."
    
    # Create temporary crontab
    cat > /tmp/ajsender-cron << 'CRON_EOF'
# AJ Sender automated tasks
# Backup every day at 2 AM
0 2 * * * /path/to/ajsender/scripts/backup.sh > /dev/null 2>&1

# Health check every 5 minutes
*/5 * * * * /path/to/ajsender/scripts/monitor.sh --auto-restart > /dev/null 2>&1

# Clean up old logs every week
0 3 * * 0 find /path/to/ajsender/logs -name "*.log" -mtime +30 -delete

# Update system packages every month
0 4 1 * * apt-get update && apt-get upgrade -y > /dev/null 2>&1
CRON_EOF
    
    # Replace path placeholders
    sed -i "s|/path/to/ajsender|$(pwd)|g" /tmp/ajsender-cron
    
    # Install crontab
    crontab -l 2>/dev/null | cat - /tmp/ajsender-cron | crontab -
    rm /tmp/ajsender-cron
    
    print_success "Cron jobs configured"
}

# Main optimization function
main() {
    echo "============================================="
    echo "⚡ AJ Sender System Optimization"
    echo "$(date)"
    echo "============================================="
    
    optimize_docker
    echo
    
    optimize_system
    echo
    
    setup_log_rotation
    echo
    
    setup_cron_jobs
    echo
    
    print_success "✅ System optimization completed!"
    print_warning "Please reboot the system to apply all optimizations"
    
    echo "============================================="
}

# Run optimization
main "$@"
