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
    logger -t backhaul-watchdog "Installation failed: root privileges required"
    exit 1
fi

echo -e "${CYAN}🔧 Backhaul Watchdog Installation${NC}"

# Paths
SCRIPT_DIR="/usr/local/bin/backhaul_watchdog"
CONFIG_DIR="/etc/backhaul_watchdog"
SYSTEMD_DIR="/etc/systemd/system"
TEMP_DIR="/tmp/backhaul-watchdog-install"
REPO_URL="https://github.com/power0matin/backhaul-watchdog"

# Check dependencies
for cmd in git curl bc; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ $cmd is required but not installed${NC}"
        logger -t backhaul-watchdog "Missing dependency: $cmd"
        exit 1
    fi
done

# Create directories
mkdir -p "$SCRIPT_DIR" "$CONFIG_DIR" "$SYSTEMD_DIR" "$TEMP_DIR"

# Check if running from a local repository or curl
echo -e "${GREEN}📝 Copying files...${NC}"
if [[ -d "core" && -n "$(ls -A core/*.sh 2>/dev/null)" ]]; then
    # Running from local repository
    for script in backhaul_watchdog.sh helpers.sh update.sh uninstall.sh setup_endpoints.sh; do
        if [[ ! -f "core/$script" ]]; then
            echo -e "${RED}❌ $script not found in core/${NC}"
            logger -t backhaul-watchdog "$script not found in core/"
            exit 1
        fi
        cp "core/$script" "$SCRIPT_DIR/" || {
            echo -e "${RED}❌ Failed to copy $script${NC}"
            logger -t backhaul-watchdog "Failed to copy $script"
            exit 1
        }
    done
    if [[ ! -f "config/config_example.conf" ]]; then
        echo -e "${RED}❌ config_example.conf not found in config/${NC}"
        logger -t backhaul-watchdog "config_example.conf not found in config/"
        exit 1
    fi
    cp config/config_example.conf "$CONFIG_DIR/backhaul_watchdog.conf" || {
        echo -e "${RED}❌ Failed to copy config file${NC}"
        logger -t backhaul-watchdog "Failed to copy config file"
        exit 1
    }
    for file in backhaul_watchdog.service backhaul_watchdog.timer; do
        if [[ ! -f "systemd/$file" ]]; then
            echo -e "${RED}❌ $file not found in systemd/${NC}"
            logger -t backhaul-watchdog "$file not found in systemd/"
            exit 1
        fi
        cp "systemd/$file" "$SYSTEMD_DIR/" || {
            echo -e "${RED}❌ Failed to copy $file${NC}"
            logger -t backhaul-watchdog "Failed to copy $file"
            exit 1
        }
    done
else
    # Running via curl, download files from GitHub
    echo -e "${GREEN}📥 Downloading files from $REPO_URL...${NC}"
    for script in backhaul_watchdog.sh helpers.sh update.sh uninstall.sh setup_endpoints.sh; do
        curl -Ls "$REPO_URL/raw/main/core/$script" -o "$SCRIPT_DIR/$script" || {
            echo -e "${RED}❌ Failed to download $script from $REPO_URL/raw/main/core/$script${NC}"
            logger -t backhaul-watchdog "Failed to download $script"
            exit 1
        }
        if [[ ! -s "$SCRIPT_DIR/$script" ]]; then
            echo -e "${RED}❌ Downloaded $script is empty or invalid${NC}"
            logger -t backhaul-watchdog "Downloaded $script is empty or invalid"
            exit 1
        }
    done
    curl -Ls "$REPO_URL/raw/main/config/config_example.conf" -o "$CONFIG_DIR/backhaul_watchdog.conf" || {
        echo -e "${RED}❌ Failed to download config_example.conf from $REPO_URL/raw/main/config/config_example.conf${NC}"
        logger -t backhaul-watchdog "Failed to download config file"
        exit 1
    }
    if [[ ! -s "$CONFIG_DIR/backhaul_watchdog.conf" ]]; then
        echo -e "${RED}❌ Downloaded config_example.conf is empty or invalid${NC}"
        logger -t backhaul-watchdog "Downloaded config file is empty or invalid"
        exit 1
    }
    for file in backhaul_watchdog.service backhaul_watchdog.timer; do
        curl -Ls "$REPO_URL/raw/main/systemd/$file" -o "$SYSTEMD_DIR/$file" || {
            echo -e "${RED}❌ Failed to download $file from $REPO_URL/raw/main/systemd/$file${NC}"
            logger -t backhaul-watchdog "Failed to download $file"
            exit 1
        }
        if [[ ! -s "$SYSTEMD_DIR/$file" ]]; then
            echo -e "${RED}❌ Downloaded $file is empty or invalid${NC}"
            logger -t backhaul-watchdog "Downloaded $file is empty or invalid"
            exit 1
        }
    done
fi

# Set permissions
chmod +x "$SCRIPT_DIR/"*.sh
chmod 600 "$CONFIG_DIR/backhaul_watchdog.conf"

# Unmask service and timer if masked
for unit in backhaul-watchdog.service backhaul-watchdog.timer; do
    if systemctl is-enabled "$unit" 2>/dev/null | grep -q "masked"; then
        echo -e "${GREEN}🔧 Unmasking $unit...${NC}"
        systemctl unmask "$unit" || {
            echo -e "${RED}❌ Failed to unmask $unit${NC}"
            logger -t backhaul-watchdog "Failed to unmask $unit"
            exit 1
        }
    fi
done

# Create alias
echo -e "${GREEN}🔗 Creating CLI alias 'watchdog'...${NC}"
echo "alias watchdog='bash $SCRIPT_DIR/backhaul_watchdog.sh'" >> /root/.bashrc

# Run initial setup
echo -e "${GREEN}🔧 Running initial setup...${NC}"
bash "$SCRIPT_DIR/setup_endpoints.sh" || {
    echo -e "${RED}❌ Failed to run initial setup${NC}"
    logger -t backhaul-watchdog "Failed to run initial setup"
    exit 1
}

# Reload and start systemd
echo -e "${GREEN}🔄 Reloading systemd...${NC}"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable backhaul-watchdog.timer || {
    echo -e "${RED}❌ Failed to enable backhaul-watchdog.timer${NC}"
    logger -t backhaul-watchdog "Failed to enable backhaul-watchdog.timer"
    exit 1
}
systemctl start backhaul-watchdog.timer || {
    echo -e "${RED}❌ Failed to start backhaul-watchdog.timer${NC}"
    logger -t backhaul-watchdog "Failed to start backhaul-watchdog.timer"
    exit 1
}

# Clean up
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Installation complete! Run 'watchdog' to manage the service.${NC}"
logger -t backhaul-watchdog "Installation completed successfully"