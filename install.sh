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

# Repository URL
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
    cp core/backhaul_watchdog.sh core/helpers.sh core/update.sh core/uninstall.sh "$SCRIPT_DIR/" || {
        echo -e "${RED}❌ Failed to copy core scripts${NC}"
        logger -t backhaul-watchdog "Failed to copy core scripts"
        exit 1
    }
    cp config/config_example.conf "$CONFIG_DIR/backhaul_watchdog.conf" || {
        echo -e "${RED}❌ Failed to copy config file${NC}"
        logger -t backhaul-watchdog "Failed to copy config file"
        exit 1
    }
    cp config/setup_endpoints.sh "$SCRIPT_DIR/" || {
        echo -e "${RED}❌ Failed to copy setup script${NC}"
        logger -t backhaul-watchdog "Failed to copy setup script"
        exit 1
    }
    cp systemd/backhaul_watchdog.service systemd/backhaul_watchdog.timer "$SYSTEMD_DIR/" || {
        echo -e "${RED}❌ Failed to copy systemd files${NC}"
        logger -t backhaul-watchdog "Failed to copy systemd files"
        exit 1
    }
    cp install.sh /usr/local/bin/ || {
        echo -e "${RED}❌ Failed to copy install script${NC}"
        logger -t backhaul-watchdog "Failed to copy install script"
        exit 1
    }
else
    # Running via curl, download files from GitHub
    echo -e "${GREEN}📥 Downloading files from $REPO_URL...${NC}"
    for script in backhaul_watchdog.sh helpers.sh update.sh uninstall.sh; do
        curl -Ls "$REPO_URL/raw/main/core/$script" -o "$SCRIPT_DIR/$script" || {
            echo -e "${RED}❌ Failed to download $script${NC}"
            logger -t backhaul-watchdog "Failed to download $script"
            exit 1
        }
    done
    curl -Ls "$REPO_URL/raw/main/config/config_example.conf" -o "$CONFIG_DIR/backhaul_watchdog.conf" || {
        echo -e "${RED}❌ Failed to download config file${NC}"
        logger -t backhaul-watchdog "Failed to download config file"
        exit 1
    }
    curl -Ls "$REPO_URL/raw/main/config/setup_endpoints.sh" -o "$SCRIPT_DIR/setup_endpoints.sh" || {
        echo -e "${RED}❌ Failed to download setup script${NC}"
        logger -t backhaul-watchdog "Failed to download setup script"
        exit 1
    }
    curl -Ls "$REPO_URL/raw/main/systemd/backhaul_watchdog.service" -o "$SYSTEMD_DIR/backhaul_watchdog.service" || {
        echo -e "${RED}❌ Failed to download service file${NC}"
        logger -t backhaul-watchdog "Failed to download service file"
        exit 1
    }
    curl -Ls "$REPO_URL/raw/main/systemd/backhaul_watchdog.timer" -o "$SYSTEMD_DIR/backhaul_watchdog.timer" || {
        echo -e "${RED}❌ Failed to download timer file${NC}"
        logger -t backhaul-watchdog "Failed to download timer file"
        exit 1
    }
    curl -Ls "$REPO_URL/raw/main/install.sh" -o /usr/local/bin/install.sh || {
        echo -e "${RED}❌ Failed to download install script${NC}"
        logger -t backhaul-watchdog "Failed to download install script"
        exit 1
    }
fi

# Set permissions
chmod +x "$SCRIPT_DIR/"*.sh /usr/local/bin/install.sh
chmod 600 "$CONFIG_DIR/backhaul_watchdog.conf"

# Unmask service if masked
if systemctl is-enabled backhaul-watchdog.service 2>/dev/null | grep -q "masked"; then
    echo -e "${GREEN}🔧 Unmasking backhaul-watchdog.service...${NC}"
    systemctl unmask backhaul-watchdog.service || {
        echo -e "${RED}❌ Failed to unmask backhaul-watchdog.service${NC}"
        logger -t backhaul-watchdog "Failed to unmask backhaul-watchdog.service"
        exit 1
    }
fi

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