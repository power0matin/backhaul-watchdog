#!/bin/bash
set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[1;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="/usr/local/bin/backhaul_watchdog"
CONFIG_DIR="/etc/backhaul_watchdog"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

echo -e "${CYAN}🔄 Updating Backhaul Watchdog...${NC}"

# Repository URL (replace with your actual GitHub repo)
REPO_URL="https://github.com/yourusername/backhaul-watchdog"
TEMP_DIR="/tmp/backhaul-watchdog-update"

# Download latest version
echo -e "${GREEN}📥 Downloading latest version...${NC}"
rm -rf "$TEMP_DIR"
git clone "$REPO_URL" "$TEMP_DIR" || {
    echo -e "${RED}❌ Failed to clone repository${NC}"
    exit 1
}

# Copy new files
echo -e "${GREEN}📝 Updating files...${NC}"
cp -f "$TEMP_DIR/core/"*.sh "$SCRIPT_DIR/"
cp -f "$TEMP_DIR/install.sh" /usr/local/bin/
cp -f "$TEMP_DIR/systemd/backhaul_watchdog.service" /etc/systemd/system/
cp -f "$TEMP_DIR/config/config_example.conf" "$CONFIG_DIR/"
chmod +x "$SCRIPT_DIR/"*.sh /usr/local/bin/install.sh
chmod 600 "$CONFIG_DIR/config_example.conf"

# Reload systemd
echo -e "${GREEN}🔄 Reloading systemd...${NC}"
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart backhaul-watchdog.timer

# Clean up
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✅ Update complete!${NC}"