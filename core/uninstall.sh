#!/bin/bash
set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[1;36m'
NC='\033[0m'

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

echo -e "${CYAN}🗑️ Uninstalling Backhaul Watchdog...${NC}"

# Stop and disable services
echo -e "${GREEN}🛑 Stopping services...${NC}"
systemctl stop backhaul-watchdog.timer || true
systemctl disable backhaul-watchdog.timer || true

# Remove systemd files
echo -e "${GREEN}🗑️ Removing systemd files...${NC}"
rm -f /etc/systemd/system/backhaul-watchdog.service
rm -f /etc/systemd/system/backhaul-watchdog.timer

# Remove files
echo -e "${GREEN}🗑️ Removing watchdog files...${NC}"
rm -rf /etc/backhaul_watchdog
rm -rf /var/lib/backhaul_watchdog
rm -rf /usr/local/bin/backhaul_watchdog
rm -f /usr/local/bin/install.sh

# Remove alias
echo -e "${GREEN}🗑️ Removing CLI alias...${NC}"
sed -i '/alias watchdog=/d' /root/.bashrc

# Reload systemd
echo -e "${GREEN}🔄 Reloading systemd...${NC}"
systemctl daemon-reexec
systemctl daemon-reload

echo -e "${GREEN}✅ Uninstallation complete!${NC}"