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
    logger -t backhaul-watchdog "Uninstallation failed: root privileges required"
    exit 1
fi

echo -e "${CYAN}🗑️ Uninstalling Backhaul Watchdog...${NC}"

# Stop services
echo -e "${GREEN}🛑 Stopping services...${NC}"
systemctl stop backhaul-watchdog.timer 2>/dev/null || true
systemctl disable backhaul-watchdog.timer 2>/dev/null || true
systemctl stop backhaul-watchdog.service 2>/dev/null || true
systemctl disable backhaul-watchdog.service 2>/dev/null || true

# Remove systemd files
echo -e "${GREEN}🗑️ Removing systemd files...${NC}"
rm -f /etc/systemd/system/backhaul-watchdog.service /etc/systemd/system/backhaul-watchdog.timer

# Remove watchdog files
echo -e "${GREEN}🗑️ Removing watchdog files...${NC}"
rm -rf /usr/local/bin/backhaul_watchdog /etc/backhaul_watchdog /var/lib/backhaul_watchdog /usr/local/bin/watchdog

# Remove alias
echo -e "${GREEN}🗑️ Removing CLI alias...${NC}"
sed -i '/alias watchdog=/d' /root/.bashrc

# Reload systemd
echo -e "${GREEN}🔄 Reloading systemd...${NC}"
systemctl daemon-reexec
systemctl daemon-reload

echo -e "${GREEN}✅ Uninstallation complete!${NC}"
logger -t backhaul-watchdog "Uninstallation completed successfully"