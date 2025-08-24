#!/bin/bash

echo "🧪 Testing AJ Sender Setup"
echo "=========================="

# Test if all required files exist
echo "Checking files..."
files=(
    "frontend/src/App.tsx"
    "frontend/src/components/Dashboard.tsx"
    "frontend/src/components/WhatsAppAuth.tsx"
    "frontend/src/components/CSVUpload.tsx"
    "frontend/src/components/FloatingHearts.tsx"
    "backend/server.js"
    "docker-compose.yml"
)

all_good=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        all_good=false
    fi
done

if [ "$all_good" = true ]; then
    echo ""
    echo "🎉 All files are in place!"
    echo "Run './setup-and-start.sh' to start the application"
else
    echo ""
    echo "❌ Some files are missing. Please run all the setup commands first."
fi
