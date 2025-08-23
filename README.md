# 🚀 AJ Sender - WhatsApp Bulk Messaging Platform

A professional WhatsApp bulk messaging platform built with React, Node.js, and Docker.

## ✨ Features

- **Modern UI/UX** - Beautiful dashboard with dark/light mode
- **WhatsApp Integration** - Send bulk messages via WhatsApp Web
- **Real-time Analytics** - Track campaign progress and metrics
- **Contact Management** - Import contacts from CSV
- **Campaign Management** - Create and monitor campaigns
- **Production Ready** - SSL, monitoring, backups

## 🚀 Quick Start

```bash
# Start the application
docker-compose up -d --build

# Access your platform
# Frontend: http://localhost:3000
# API: http://localhost:3001
# Health: http://localhost:3001/health
```

## 🛠️ Service Management

```bash
# Service control
./scripts/service.sh start        # Start services
./scripts/service.sh stop         # Stop services
./scripts/service.sh restart      # Restart services
./scripts/service.sh status       # Show status
./scripts/service.sh logs         # Show logs
./scripts/service.sh health       # Health check

# Backup
./scripts/backup.sh               # Create backup
```

## 🏗️ Architecture

- **Frontend**: React 18 + TypeScript + Tailwind CSS
- **Backend**: Node.js + Express + SQLite
- **Infrastructure**: Docker + Caddy + SSL
- **Features**: Real-time progress, Campaign management, Contact import

## 💝 Made with Love

This project is serious. It's for my girl. This isn't toy software.
Clean, focused, and complete.

---

AJ Sender v2.0 - Professional WhatsApp Bulk Messaging Platform
