#!/bin/bash
# Self-healing installer for AJ Sender

set -e

LOG_FILE="./install.log"
SCRIPTS=(
    "backup.sh"
    "restore.sh"
    "monitor.sh"
    "verify-deployment.sh"
    "setup-ssl.sh"
    "update.sh"
    "install.sh"
    "service.sh"
    "optimize.sh"
)

log() {
    echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting self-healing install process..."

for script in "${SCRIPTS[@]}"; do
    if [ -f "./scripts/$script" ]; then
        chmod +x "./scripts/$script"
        log "✅ Found and fixed permissions for: $script"
    else
        log "❌ MISSING: $script"
        log "⚠️ Creating stub for $script..."
        echo -e "#!/bin/bash\necho '[WARN] $script stub executed. Needs implementation.'" > "./scripts/$script"
        chmod +x "./scripts/$script"
        log "✅ Stub created for: $script"
    fi
done

log "🎉 Self-healing install complete. You're all patched up, baby."
