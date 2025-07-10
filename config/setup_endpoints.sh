#!/bin/bash
set -euo pipefail

# Color codes
GREEN='\033[0;32m'
CYAN='\033[1;36m'
RED='\033[0;31m'
NC='\033[0m'

# Paths
CONFIG_DIR="/etc/backhaul_watchdog"
CONFIG_FILE="$CONFIG_DIR/backhaul_watchdog.conf"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    logger -t backhaul-watchdog "Setup failed: root privileges required"
    exit 1
fi

# Load helpers
source /usr/local/bin/backhaul_watchdog/helpers.sh

echo -e "${CYAN}🔧 Setup Backhaul Watchdog Endpoints${NC}"

# Default values
DEFAULT_PING_TARGETS="8.8.8.8 1.1.1.1"
DEFAULT_MAX_LATENCY=200
DEFAULT_CHECK_INTERVAL=30
DEFAULT_SERVICE_NAME="backhaul"
DEFAULT_COOLDOWN=300
DEFAULT_TELEGRAM_BOT_TOKEN=""
DEFAULT_TELEGRAM_CHAT_ID=""

# Ask for user inputs
read -rp "$(echo -e ${CYAN}"Enter ping targets (space-separated IPs or domains) [default: $DEFAULT_PING_TARGETS]: "${NC})" PING_TARGETS
PING_TARGETS=${PING_TARGETS:-$DEFAULT_PING_TARGETS}
read -rp "$(echo -e ${CYAN}"Enter max latency (ms) [default: $DEFAULT_MAX_LATENCY]: "${NC})" MAX_LATENCY
MAX_LATENCY=${MAX_LATENCY:-$DEFAULT_MAX_LATENCY}
read -rp "$(echo -e ${CYAN}"Enter check interval (seconds) [default: $DEFAULT_CHECK_INTERVAL]: "${NC})" CHECK_INTERVAL
CHECK_INTERVAL=${CHECK_INTERVAL:-$DEFAULT_CHECK_INTERVAL}
read -rp "$(echo -e ${CYAN}"Enter service name [default: $DEFAULT_SERVICE_NAME]: "${NC})" SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
read -rp "$(echo -e ${CYAN}"Enter cooldown (seconds) [default: $DEFAULT_COOLDOWN]: "${NC})" COOLDOWN
COOLDOWN=${COOLDOWN:-$DEFAULT_COOLDOWN}
read -rp "$(echo -e ${CYAN}"Enter Telegram bot token (leave empty to disable): "${NC})" TELEGRAM_BOT_TOKEN
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-$DEFAULT_TELEGRAM_BOT_TOKEN}
read -rp "$(echo -e ${CYAN}"Enter Telegram chat ID (leave empty to disable): "${NC})" TELEGRAM_CHAT_ID
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID:-$DEFAULT_TELEGRAM_CHAT_ID}

# Validate inputs
if ! validate_numeric "$MAX_LATENCY" || ! validate_numeric "$CHECK_INTERVAL" || ! validate_numeric "$COOLDOWN"; then
    echo -e "${RED}❌ MAX_LATENCY, CHECK_INTERVAL, and COOLDOWN must be numeric${NC}"
    logger -t backhaul-watchdog "Invalid numeric input during setup"
    exit 1
fi

# Validate ping targets
for TARGET in $PING_TARGETS; do
    if ! validate_ip_or_domain "$TARGET"; then
        echo -e "${RED}❌ Invalid IP or domain: $TARGET${NC}"
        logger -t backhaul-watchdog "Invalid ping target: $TARGET"
        exit 1
    fi
done

# Create config file
echo -e "${GREEN}📝 Writing config file to ${CONFIG_FILE}...${NC}"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
# Backhaul Watchdog Configuration
PING_TARGETS="$PING_TARGETS"
MAX_LATENCY=$MAX_LATENCY
CHECK_INTERVAL=$CHECK_INTERVAL
SERVICE_NAME="$SERVICE_NAME"
COOLDOWN=$COOLDOWN
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
chmod 600 "$CONFIG_FILE"

# Update timer with CHECK_INTERVAL
echo -e "${GREEN}🕒 Updating systemd timer...${NC}"
cat > /etc/systemd/system/backhaul-watchdog.timer <<EOF
[Unit]
Description=Timer for Backhaul Watchdog Service

[Timer]
OnBootSec=1min
OnUnitActiveSec=${CHECK_INTERVAL}s
Unit=backhaul-watchdog.service

[Install]
WantedBy=timers.target
EOF

# Reload systemd
systemctl daemon-reload
systemctl restart backhaul-watchdog.timer

echo -e "${GREEN}✅ Configuration setup complete!${NC}"
logger -t backhaul-watchdog "Configuration setup completed"