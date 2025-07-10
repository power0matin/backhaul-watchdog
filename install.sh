#!/bin/bash
set -euo pipefail

# Color codes
GREEN='\033[0;32m'
CYAN='\033[1;36m'
RED='\033[0;31m'
NC='\033[0m'

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

echo -e "${CYAN}🔧 Backhaul Watchdog Installation${NC}"

# Paths
SCRIPT_DIR="/usr/local/bin/backhaul_watchdog"
CONFIG_DIR="/etc/backhaul_watchdog"
SYSTEMD_DIR="/etc/systemd/system"

# Create directories
mkdir -p "$SCRIPT_DIR" "$CONFIG_DIR" "$SYSTEMD_DIR"

# Copy files
echo -e "${GREEN}📝 Copying files...${NC}"
cp core/*.sh "$SCRIPT_DIR/"
cp config/config_example.conf "$CONFIG_DIR/"
cp config/setup_endpoints.sh "$SCRIPT_DIR/"
cp systemd/backhaul_watchdog.service "$SYSTEMD_DIR/"
cp systemd/backhaul_watchdog.timer "$SYSTEMD_DIR/"
cp install.sh /usr/local/bin/

# Set permissions
chmod +x "$SCRIPT_DIR/"*.sh /usr/local/bin/install.sh
chmod 600 "$CONFIG_DIR/config_example.conf"

# Create alias
echo -e "${GREEN}🔗 Creating CLI alias 'watchdog'...${NC}"
echo "alias watchdog='bash $SCRIPT_DIR/backhaul_watchdog.sh'" >> /root/.bashrc

# Run initial setup
echo -e "${GREEN}🔧 Running initial setup...${NC}"
bash "$SCRIPT_DIR/setup_endpoints.sh"

# Reload and start systemd
echo -e "${GREEN}🔄 Reloading systemd...${NC}"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now backhaul-watchdog.timer

echo -e "${GREEN}✅ Installation complete! Run 'watchdog' to manage the service.${NC}"