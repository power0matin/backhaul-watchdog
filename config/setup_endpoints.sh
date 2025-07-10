#!/bin/bash
set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[1;36m'
NC='\033[0m'

# Paths
CONFIG_DIR="/etc/backhaul_watchdog"
CONFIG_FILE="$CONFIG_DIR/backhaul_watchdog.conf"
SYSTEMD_DIR="/etc/systemd/system"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    logger -t backhaul-watchdog "Setup failed: root privileges required"
    exit 1
fi

echo -e "${CYAN}🔧 Setup Backhaul Watchdog Endpoints${NC}"

# Default values
DEFAULT_PING_TARGETS="8.8.8.8 1.1.1.1"
DEFAULT_MAX_LATENCY=200
DEFAULT_CHECK_INTERVAL=30
DEFAULT_SERVICE_NAME="backhaul"
DEFAULT_COOLDOWN=300
DEFAULT_TELEGRAM_BOT_TOKEN=""
DEFAULT_TELEGRAM_CHAT_ID=""

# Prompt for configuration
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
if ! [[ "$MAX_LATENCY" =~ ^[0-9]+$ ]] || ! [[ "$CHECK_INTERVAL" =~ ^[0-9]+$ ]] || ! [[ "$COOLDOWN" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}❌ MAX_LATENCY, CHECK_INTERVAL, and COOLDOWN must be numeric${NC}"
    logger -t backhaul-watchdog "Setup failed: Invalid numeric input"
    exit 1
fi

for TARGET in $PING_TARGETS; do
    if ! [[ "$TARGET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && ! [[ "$TARGET" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ Invalid IP or domain: $TARGET${NC}"
        logger -t backhaul-watchdog "Setup failed: Invalid IP or domain $TARGET"
        exit 1
    fi
done

# Write config file
echo -e "${GREEN}📝 Writing config file to $CONFIG_FILE...${NC}"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" << EOF
PING_TARGETS="$PING_TARGETS"
MAX_LATENCY=$MAX_LATENCY
CHECK_INTERVAL=$CHECK_INTERVAL
SERVICE_NAME="$SERVICE_NAME"
COOLDOWN=$COOLDOWN
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
chmod 600 "$CONFIG_FILE"

# Update systemd timer
echo -e "${GREEN}🕒 Updating systemd timer...${NC}"
sed -i "s/OnUnitActiveSec=.*/OnUnitActiveSec=${CHECK_INTERVAL}s/" "$SYSTEMD_DIR/backhaul-watchdog.timer"
systemctl daemon-reload
systemctl restart backhaul-watchdog.timer || {
    echo -e "${RED}❌ Failed to restart backhaul-watchdog.timer${NC}"
    logger -t backhaul-watchdog "Failed to restart backhaul-watchdog.timer"
    exit 1
}

echo -e "${GREEN}✅ Setup complete!${NC}"
logger -t backhaul-watchdog "Setup completed successfully"