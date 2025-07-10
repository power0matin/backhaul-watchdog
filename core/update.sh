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
       logger -t backhaul-watchdog "Update failed: root privileges required"
       exit 1
   fi

   echo -e "${CYAN}🔄 Updating Backhaul Watchdog...${NC}"

   # Repository URL
   REPO_URL="https://github.com/power0matin/backhaul-watchdog"
   TEMP_DIR="/tmp/backhaul-watchdog-update"

   # Download latest version
   echo -e "${GREEN}📥 Downloading latest version...${NC}"
   rm -rf "$TEMP_DIR"
   git clone "$REPO_URL" "$TEMP_DIR" || {
       echo -e "${RED}❌ Failed to clone repository from $REPO_URL${NC}"
       logger -t backhaul-watchdog "Failed to clone repository from $REPO_URL"
       exit 1
   }

   # Check if core directory exists
   if [[ ! -d "$TEMP_DIR/core" || -z "$(ls -A "$TEMP_DIR/core/"*.sh)" ]]; then
       echo -e "${RED}❌ Core directory or scripts not found in repository${NC}"
       logger -t backhaul-watchdog "Core directory or scripts not found in repository"
       exit 1
   fi

   # Copy new files
   echo -e "${GREEN}📝 Updating files...${NC}"
   cp -f "$TEMP_DIR/core/"*.sh "$SCRIPT_DIR/" || {
       echo -e "${RED}❌ Failed to copy core scripts${NC}"
       logger -t backhaul-watchdog "Failed to copy core scripts"
       exit 1
   }
   cp -f "$TEMP_DIR/install.sh" /usr/local/bin/ || {
       echo -e "${RED}❌ Failed to copy install script${NC}"
       logger -t backhaul-watchdog "Failed to copy install script"
       exit 1
   }
   cp -f "$TEMP_DIR/systemd/backhaul_watchdog.service" /etc/systemd/system/ || {
       echo -e "${RED}❌ Failed to copy service file${NC}"
       logger -t backhaul-watchdog "Failed to copy service file"
       exit 1
   }
   cp -f "$TEMP_DIR/systemd/backhaul_watchdog.timer" /etc/systemd/system/ || {
       echo -e "${RED}❌ Failed to copy timer file${NC}"
       logger -t backhaul-watchdog "Failed to copy timer file"
       exit 1
   }
   cp -f "$TEMP_DIR/config/config_example.conf" "$CONFIG_DIR/" || {
       echo -e "${RED}❌ Failed to copy config file${NC}"
       logger -t backhaul-watchdog "Failed to copy config file"
       exit 1
   }
   cp -f "$TEMP_DIR/config/setup_endpoints.sh" "$SCRIPT_DIR/" || {
       echo -e "${RED}❌ Failed to copy setup script${NC}"
       logger -t backhaul-watchdog "Failed to copy setup script"
       exit 1
   }
   chmod +x "$SCRIPT_DIR/"*.sh /usr/local/bin/install.sh
   chmod 600 "$CONFIG_DIR/config_example.conf"

   # Reload systemd
   echo -e "${GREEN}🔄 Reloading systemd...${NC}"
   systemctl daemon-reexec
   systemctl daemon-reload
   systemctl restart backhaul-watchdog.timer || {
       echo -e "${RED}❌ Failed to restart backhaul-watchdog.timer${NC}"
       logger -t backhaul-watchdog "Failed to restart backhaul-watchdog.timer"
       exit 1
   }

   # Clean up
   rm -rf "$TEMP_DIR"
   echo -e "${GREEN}✅ Update complete!${NC}"
   logger -t backhaul-watchdog "Update completed successfully"